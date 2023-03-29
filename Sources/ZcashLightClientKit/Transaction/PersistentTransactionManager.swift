//
//  PendingTransactionsManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/26/19.
//

import Foundation

class PersistentTransactionManager: OutboundTransactionManager {
    let repository: PendingTransactionRepository
    let encoder: TransactionEncoder
    let service: LightWalletService
    let queue: DispatchQueue
    let network: NetworkType
    let logger: Logger
    
    init(
        encoder: TransactionEncoder,
        service: LightWalletService,
        repository: PendingTransactionRepository,
        networkType: NetworkType,
        logger: Logger
    ) {
        self.repository = repository
        self.encoder = encoder
        self.service = service
        self.network = networkType
        self.queue = DispatchQueue.init(label: "PersistentTransactionManager.serial.queue", qos: .userInitiated)
        self.logger = logger
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
            throw ZcashError.persistentTransManagerCantCreateTransaction(recipient, accountIndex, zatoshi)
        }
        logger.debug("pending transaction \(String(describing: insertedTx.id)) created")
        return insertedTx
    }
    
    func encodeShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        let transaction = try await self.encoder.createShieldingTransaction(
            spendingKey: spendingKey,
            shieldingThreshold: shieldingThreshold,
            memoBytes: try pendingTransaction.memo?.intoMemoBytes(),
            from: pendingTransaction.accountIndex
        )

        var pending = pendingTransaction
        pending.encodeAttempts += 1
        pending.raw = transaction.raw
        pending.rawTransactionId = transaction.rawID
        pending.expiryHeight = transaction.expiryHeight ?? BlockHeight.empty()
        pending.minedHeight = transaction.minedHeight ?? BlockHeight.empty()

        try self.repository.update(pending)

        return pending
    }

    func encode(
        spendingKey: UnifiedSpendingKey,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        do {
            var toAddress: String?
            switch pendingTransaction.recipient {
            case .address(let addr):
                toAddress = addr.stringEncoded
            case .internalAccount:
                break
            }

            guard let toAddress else {
                throw ZcashError.persistentTransManagerEncodeUknownToAddress(pendingTransaction)
            }
            
            let transaction = try await self.encoder.createTransaction(
                spendingKey: spendingKey,
                zatoshi: pendingTransaction.value,
                to: toAddress,
                memoBytes: try pendingTransaction.memo?.intoMemoBytes(),
                from: pendingTransaction.accountIndex
            )

            var pending = pendingTransaction
            pending.encodeAttempts += 1
            pending.raw = transaction.raw
            pending.rawTransactionId = transaction.rawID
            pending.expiryHeight = transaction.expiryHeight ?? BlockHeight.empty()
            pending.minedHeight = transaction.minedHeight ?? BlockHeight.empty()
            
            try self.repository.update(pending)
            
            return pending
        } catch {
            try await self.updateOnFailure(transaction: pendingTransaction, error: error)
            throw error
        }
    }
    
    func submit(
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity {
        guard let txId = pendingTransaction.id else {
            // this transaction is not stored
            throw ZcashError.persistentTransManagerSubmitTransactionIDMissing(pendingTransaction)
        }
        
        do {
            guard let storedTx = try self.repository.find(by: txId) else {
                throw ZcashError.persistentTransManagerSubmitTransactionNotFound(pendingTransaction)
            }
            
            guard !storedTx.isCancelled  else {
                logger.debug("ignoring cancelled transaction \(storedTx)")
                throw ZcashError.persistentTransManagerSubmitTransactionCanceled(storedTx)
            }
            
            guard let raw = storedTx.raw else {
                logger.debug("INCONSISTENCY: attempt to send pending transaction \(txId) that has not raw data")
                throw ZcashError.persistentTransManagerSubmitTransactionRawDataMissing(storedTx)
            }
            
            let response = try await self.service.submit(spendTransaction: raw)
            let transaction = try await self.update(transaction: storedTx, on: response)
            
            guard response.errorCode >= 0 else {
                throw ZcashError.persistentTransManagerSubmitFailed(transaction, Int(response.errorCode))
            }
            
            return transaction
        } catch {
            try await self.updateOnFailure(transaction: pendingTransaction, error: error)
            throw error
        }
    }
    
    func applyMinedHeight(pendingTransaction: PendingTransactionEntity, minedHeight: BlockHeight) async throws -> PendingTransactionEntity {
        guard let id = pendingTransaction.id else {
            throw ZcashError.persistentTransManagerApplyMinedHeightTransactionIDMissing(pendingTransaction)
        }
        
        guard var transaction = try repository.find(by: id) else {
            throw ZcashError.persistentTransManagerApplyMinedHeightTransactionNotFound(pendingTransaction)
        }
        
        transaction.minedHeight = minedHeight
        guard let pendingTxId = pendingTransaction.id else {
            throw ZcashError.persistentTransManagerApplyMinedHeightTransactionIDMissing(pendingTransaction)
        }
        try repository.applyMinedHeight(minedHeight, id: pendingTxId)
        return transaction
    }
    
    func handleReorg(at height: BlockHeight) async throws {
        let affectedTxs = try await allPendingTransactions()
            .filter({ $0.minedHeight >= height })
        
        try affectedTxs
            .map { transaction -> PendingTransactionEntity in
                var updatedTx = transaction
                updatedTx.minedHeight = -1
                return updatedTx
            }
            .forEach { try self.repository.update($0) }
    }
    
    func cancel(pendingTransaction: PendingTransactionEntity) async -> Bool {
        guard let id = pendingTransaction.id else { return false }
        
        guard let transaction = try? repository.find(by: id) else { return false }
        
        guard !transaction.isSubmitted else { return false }
        
        guard (try? repository.cancel(transaction)) != nil else { return false }

        return true
    }
    
    func allPendingTransactions() async throws -> [PendingTransactionEntity] {
        try repository.getAll()
    }
    
    // MARK: other functions
    private func updateOnFailure(transaction: PendingTransactionEntity, error: Error) async throws {
        var pending = transaction
        pending.errorMessage = "\(error)"
        pending.encodeAttempts = transaction.encodeAttempts + 1
        try self.repository.update(pending)
    }
    
    private func update(transaction: PendingTransactionEntity, on sendResponse: LightWalletServiceResponse) async throws -> PendingTransactionEntity {
        var pendingTx = transaction
        pendingTx.submitAttempts += 1
        let error = sendResponse.errorCode < 0
        pendingTx.errorCode = error ? Int(sendResponse.errorCode) : nil
        pendingTx.errorMessage = error ? sendResponse.errorMessage : nil
        try repository.update(pendingTx)
        return pendingTx
    }
    
    func delete(pendingTransaction: PendingTransactionEntity) async throws {
        try repository.delete(pendingTransaction)
    }

    func closeDBConnection() {
        repository.closeDBConnection()
    }
}

enum OutboundTransactionManagerBuilder {
    static func build(initializer: Initializer) -> OutboundTransactionManager {
        PersistentTransactionManager(
            encoder: TransactionEncoderbuilder.build(initializer: initializer),
            service: initializer.lightWalletService,
            repository: PendingTransactionRepositoryBuilder.build(initializer: initializer),
            networkType: initializer.network.networkType,
            logger: initializer.logger
        )
    }
}

enum PendingTransactionRepositoryBuilder {
    static func build(initializer: Initializer) -> PendingTransactionRepository {
        PendingTransactionSQLDAO(
            dbProvider: SimpleConnectionProvider(path: initializer.pendingDbURL.path, readonly: false),
            logger: initializer.logger
        )
    }
}

enum TransactionEncoderbuilder {
    static func build(initializer: Initializer) -> TransactionEncoder {
        WalletTransactionEncoder(initializer: initializer)
    }
}
