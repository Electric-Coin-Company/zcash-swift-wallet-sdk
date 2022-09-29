//
//  PendingTransactionsManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/26/19.
//

import Foundation

enum TransactionManagerError: Error {
    case couldNotCreateSpend(toAddress: String, account: Int, zatoshi: Zatoshi)
    case encodingFailed(PendingTransactionEntity)
    case updateFailed(PendingTransactionEntity)
    case notPending(PendingTransactionEntity)
    case cancelled(PendingTransactionEntity)
    case internalInconsistency(PendingTransactionEntity)
    case submitFailed(PendingTransactionEntity, errorCode: Int)
    case shieldingEncodingFailed(PendingTransactionEntity, reason: String)
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
        toAddress: String,
        memo: String?,
        from accountIndex: Int
    ) throws -> PendingTransactionEntity {
        guard let insertedTx = try repository.find(
            by: try repository.create(
                PendingTransaction(
                    value: zatoshi,
                    toAddress: toAddress,
                    memo: memo,
                    account: accountIndex
                )
            )
        ) else {
            throw TransactionManagerError.couldNotCreateSpend(
                toAddress: toAddress,
                account: accountIndex,
                zatoshi: zatoshi
            )
        }
        LoggerProxy.debug("pending transaction \(String(describing: insertedTx.id)) created")
        return insertedTx
    }
    
    func encodeShieldingTransaction(
        spendingKey: String,
        tsk: String,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        let derivationTool = DerivationTool(networkType: self.network)
        
        guard
            let viewingKey = try? derivationTool.deriveViewingKey(spendingKey: spendingKey),
            let zAddr = try? derivationTool.deriveShieldedAddress(viewingKey: viewingKey)
        else {
            throw TransactionManagerError.shieldingEncodingFailed(
                pendingTransaction,
                reason: "There was an error Deriving your keys"
            )
        }
        
        guard pendingTransaction.toAddress == zAddr else {
            throw TransactionManagerError.shieldingEncodingFailed(
                pendingTransaction,
                reason: """
                            the recipient address does not match your
                            derived shielded address. Shielding transactions
                            addresses must match the ones derived from your keys.
                            This is a serious error. We are not letting you encode
                            this shielding transaction because it can lead to loss
                            of funds
                        """
            )
        }
        
        do {
            let encodedTransaction = try await self.encoder.createShieldingTransaction(
                spendingKey: spendingKey,
                tSecretKey: tsk,
                memo: pendingTransaction.memo?.asZcashTransactionMemo(),
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
            throw error
        }
    }
    
    func encode(
        spendingKey: String,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        do {
            let encodedTransaction = try await self.encoder.createTransaction(
                spendingKey: spendingKey,
                zatoshi: pendingTransaction.intValue,
                to: pendingTransaction.toAddress,
                memo: pendingTransaction.memo?.asZcashTransactionMemo(),
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
            
            let response = try self.service.submit(spendTransaction: raw)
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
    
    func monitorChanges(byId: Int, observer: Any) {
        // TODO: Implement this
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
        let dao = PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.pendingDbURL.path, readonly: false))
        try dao.createrTableIfNeeded()
        return dao
    }
}

enum TransactionEncoderbuilder {
    static func build(initializer: Initializer) -> TransactionEncoder {
        WalletTransactionEncoder(initializer: initializer)
    }
}
