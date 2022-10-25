//
//  PendingTransactionsManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/26/19.
//

import Foundation

enum TransactionManagerError: Error {
    case couldNotCreateSpend(recipient: PendingTransactionRecipient, account: Int, zatoshi: Zatoshi)
    case encodingFailed(PendingTransactionEntity)
    case updateFailed(PendingTransactionEntity)
    case notPending(PendingTransactionEntity)
    case cancelled(PendingTransactionEntity)
    case internalInconsistency(PendingTransactionEntity)
    case submitFailed(PendingTransactionEntity, errorCode: Int)
    case shieldingEncodingFailed(PendingTransactionEntity, reason: String)
    case cannotEncodeInternalTx(PendingTransactionEntity)
}

class PersistentTransactionManager: OutboundTransactionManager {
    var repository: PendingTransactionRepository
    var encoder: TransactionEncoder
    var service: LightWalletService
    var queue: DispatchQueue
    var network: NetworkType
    
    init(
        encoder: TransactionEncoder,
        service: LightWalletService,
        repository: PendingTransactionRepository,
        networkType: NetworkType
    ) {
        self.repository = repository
        self.encoder = encoder
        self.service = service
        self.network = networkType
        self.queue = DispatchQueue.init(label: "PersistentTransactionManager.serial.queue", qos: .userInitiated)
    }
    
    func initSpend(
        zatoshi: Zatoshi,
        recipient: PendingTransactionRecipient,
        memo: MemoBytes?,
        from accountIndex: Int
    ) throws -> PendingTransactionEntity {
        guard let insertedTx = try repository.find(
            by: try repository.create(
                PendingTransaction(
                    value: zatoshi,
                    recipient: recipient,
                    memo: memo,
                    account: accountIndex
                )
            )
        ) else {
            throw TransactionManagerError.couldNotCreateSpend(
                recipient: recipient,
                account: accountIndex,
                zatoshi: zatoshi
            )
        }
        LoggerProxy.debug("pending transaction \(String(describing: insertedTx.id)) created")
        return insertedTx
    }
    
    func encodeShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        do {
            let encodedTransaction = try await self.encoder.createShieldingTransaction(
                spendingKey: spendingKey,
                memoBytes: try pendingTransaction.memo?.intoMemoBytes(),
                from: pendingTransaction.accountIndex
            )
            let transaction = try self.encoder.expandEncodedTransaction(encodedTransaction)
            
            var pending = pendingTransaction
            pending.encodeAttempts += 1
            pending.raw = encodedTransaction.raw
            pending.rawTransactionId = encodedTransaction.transactionId
            pending.expiryHeight = transaction.expiryHeight ?? BlockHeight.empty()
            pending.minedHeight = transaction.minedHeight ?? BlockHeight.empty()
            
            try self.repository.update(pending)
            
            return pending
        } catch StorageError.updateFailed {
            throw TransactionManagerError.updateFailed(pendingTransaction)
        } catch MemoBytes.Errors.invalidUTF8 {
            throw TransactionManagerError.shieldingEncodingFailed(pendingTransaction, reason: "Memo contains invalid UTF-8 bytes")
        } catch MemoBytes.Errors.tooLong(let length) {
            throw TransactionManagerError.shieldingEncodingFailed(pendingTransaction, reason: "Memo is too long. expected 512 bytes, received \(length)")
        } catch {
            throw error
        }
    }

    func encode(
        spendingKey: UnifiedSpendingKey,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        do {
            var toAddress: String?
            switch (pendingTransaction.recipient) {
                case .address(let addr):
                    toAddress = addr.stringEncoded
                case .internalAccount(_):
                    throw TransactionManagerError.cannotEncodeInternalTx(pendingTransaction)
            }

            let encodedTransaction = try await self.encoder.createTransaction(
                spendingKey: spendingKey,
                zatoshi: pendingTransaction.value,
                to: toAddress!,
                memoBytes: try pendingTransaction.memo?.intoMemoBytes(),
                from: pendingTransaction.accountIndex
            )
            let transaction = try self.encoder.expandEncodedTransaction(encodedTransaction)

            var pending = pendingTransaction
            pending.encodeAttempts += 1
            pending.raw = encodedTransaction.raw
            pending.rawTransactionId = encodedTransaction.transactionId
            pending.expiryHeight = transaction.expiryHeight ?? BlockHeight.empty()
            pending.minedHeight = transaction.minedHeight ?? BlockHeight.empty()
            
            try self.repository.update(pending)
            
            return pending
        } catch StorageError.updateFailed {
            throw TransactionManagerError.updateFailed(pendingTransaction)
        } catch {
            do {
                try self.updateOnFailure(transaction: pendingTransaction, error: error)
            } catch {
                throw TransactionManagerError.updateFailed(pendingTransaction)
            }
            throw error
        }
    }
    
    func submit(
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        guard let txId = pendingTransaction.id else {
            throw TransactionManagerError.notPending(pendingTransaction) // this transaction is not stored
        }
        
        do {
            guard let storedTx = try self.repository.find(by: txId) else {
                throw TransactionManagerError.notPending(pendingTransaction)
            }
            
            guard !storedTx.isCancelled  else {
                LoggerProxy.debug("ignoring cancelled transaction \(storedTx)")
                throw TransactionManagerError.cancelled(storedTx)
            }
            
            guard let raw = storedTx.raw else {
                LoggerProxy.debug("INCONSISTENCY: attempt to send pending transaction \(txId) that has not raw data")
                throw TransactionManagerError.internalInconsistency(storedTx)
            }
            
            let response = try await self.service.submit(spendTransaction: raw)
            let transaction = try self.update(transaction: storedTx, on: response)
            
            guard response.errorCode >= 0 else {
                throw TransactionManagerError.submitFailed(transaction, errorCode: Int(response.errorCode))
            }
            
            return transaction
        } catch {
            try? self.updateOnFailure(transaction: pendingTransaction, error: error)
            throw error
        }
    }
    
    func applyMinedHeight(pendingTransaction: PendingTransactionEntity, minedHeight: BlockHeight) throws -> PendingTransactionEntity {
        guard let id = pendingTransaction.id else {
            throw TransactionManagerError.internalInconsistency(pendingTransaction)
        }
        
        guard var transaction = try repository.find(by: id) else {
            throw TransactionManagerError.notPending(pendingTransaction)
        }
        
        transaction.minedHeight = minedHeight
        guard let pendingTxId = pendingTransaction.id else {
            throw TransactionManagerError.updateFailed(pendingTransaction)
        }
        do {
            try repository.applyMinedHeight(minedHeight, id: pendingTxId)
        } catch {
            throw TransactionManagerError.updateFailed(transaction)
        }
        return transaction
    }
    
    func handleReorg(at height: BlockHeight) throws {
        guard let affectedTxs = try self.allPendingTransactions()?.filter({ $0.minedHeight >= height }) else {
            return
        }
        
        try affectedTxs
            .map { transaction -> PendingTransactionEntity in
                var updatedTx = transaction
                updatedTx.minedHeight = -1
                return updatedTx
            }
            .forEach { try self.repository.update($0) }
    }
    
    func cancel(pendingTransaction: PendingTransactionEntity) -> Bool {
        guard let id = pendingTransaction.id else { return false }
        
        guard let transaction = try? repository.find(by: id) else { return false }
        
        guard !transaction.isSubmitted else { return false }
        
        guard (try? repository.cancel(transaction)) != nil else { return false }

        return true
    }
    
    func allPendingTransactions() throws -> [PendingTransactionEntity]? {
        try repository.getAll()
    }
    
    // MARK: other functions
    private func updateOnFailure(transaction: PendingTransactionEntity, error: Error) throws {
        var pending = transaction
        pending.errorMessage = error.localizedDescription
        pending.encodeAttempts = transaction.encodeAttempts + 1
        try self.repository.update(pending)
    }
    
    private func update(transaction: PendingTransactionEntity, on sendResponse: LightWalletServiceResponse) throws -> PendingTransactionEntity {
        var pendingTx = transaction
        pendingTx.submitAttempts += 1
        let error = sendResponse.errorCode < 0
        pendingTx.errorCode = error ? Int(sendResponse.errorCode) : nil
        pendingTx.errorMessage = error ? sendResponse.errorMessage : nil
        try repository.update(pendingTx)
        return pendingTx
    }
    
    func delete(pendingTransaction: PendingTransactionEntity) throws {
        do {
            try repository.delete(pendingTransaction)
        } catch {
            throw TransactionManagerError.notPending(pendingTransaction)
        }
    }
}

enum OutboundTransactionManagerBuilder {
    static func build(initializer: Initializer) throws -> OutboundTransactionManager {
        PersistentTransactionManager(
            encoder: TransactionEncoderbuilder.build(initializer: initializer),
            service: initializer.lightWalletService,
            repository: try PendingTransactionRepositoryBuilder.build(initializer: initializer),
            networkType: initializer.network.networkType
        )
    }
}

enum PendingTransactionRepositoryBuilder {
    static func build(initializer: Initializer) throws -> PendingTransactionRepository {
        PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.pendingDbURL.path, readonly: false))
    }
}

enum TransactionEncoderbuilder {
    static func build(initializer: Initializer) -> TransactionEncoder {
        WalletTransactionEncoder(initializer: initializer)
    }
}
