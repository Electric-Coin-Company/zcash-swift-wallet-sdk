//
//  PendingTransactionsManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/26/19.
//

import Foundation

enum TransactionManagerError: Error {
    case couldNotCreateSpend(toAddress: String, account: Int, zatoshi: Int)
    case encodingFailed(tx: PendingTransactionEntity)
    case updateFailed(tx: PendingTransactionEntity)
    case notPending(tx: PendingTransactionEntity)
    case cancelled(tx: PendingTransactionEntity)
    case internalInconsistency(tx: PendingTransactionEntity)
    case submitFailed(tx: PendingTransactionEntity, errorCode: Int)
}

class PersistentTransactionManager: OutboundTransactionManager {
    
    var repository: PendingTransactionRepository
    var encoder: TransactionEncoder
    var service: LightWalletService
    var queue: DispatchQueue
    init(encoder: TransactionEncoder, service: LightWalletService, repository: PendingTransactionRepository) {
        self.repository = repository
        self.encoder = encoder
        self.service = service
        self.queue = DispatchQueue.init(label: "PersistentTransactionManager.serial.queue")
    }
    
    func initSpend(zatoshi: Int, toAddress: String, memo: String?, from accountIndex: Int) throws -> PendingTransactionEntity {
        
        guard let insertedTx = try repository.find(by: try repository.create(PendingTransaction(value: zatoshi, toAddress: toAddress, memo: memo, account: accountIndex))) else {
            throw TransactionManagerError.couldNotCreateSpend(toAddress: toAddress, account: accountIndex, zatoshi: zatoshi)
        }
        print("pending transaction \(String(describing: insertedTx.id)) created")
        return insertedTx
    }
    
    func encode(spendingKey: String, pendingTransaction: PendingTransactionEntity, result: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        // FIX: change to async when librustzcash is updated to v6
        queue.sync { [weak self] in
            guard let self = self else { return }
            do {
                let encodedTransaction = try self.encoder.createTransaction(spendingKey: spendingKey, zatoshi: pendingTransaction.value, to: pendingTransaction.toAddress, memo: pendingTransaction.memo?.asZcashTransactionMemo(), from: pendingTransaction.accountIndex)
                var pending = pendingTransaction
                pending.encodeAttempts = 1
                pending.raw = encodedTransaction.raw
                pending.rawTransactionId = encodedTransaction.raw
                try self.repository.update(pending)
                
                DispatchQueue.main.async {
                    result(.success(pending))
                }
            } catch StorageError.updateFailed {
                DispatchQueue.main.async {
                    result(.failure(TransactionManagerError.updateFailed(tx: pendingTransaction)))
                }
            } catch {
                
                DispatchQueue.main.async {
                    result(.failure(error))
                }
            }
        }
    }
    
    func submit(pendingTransaction: PendingTransactionEntity, result: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        guard let txId = pendingTransaction.id else {
            result(.failure(TransactionManagerError.notPending(tx: pendingTransaction)))// this transaction is not stored
            return
        }
        // FIX: change to async when librustzcash is updated to v6
        queue.sync { [weak self] in
            guard let self = self else { return }
            do {
                guard let storedTx = try self.repository.find(by: txId) else {
                    result(.failure(TransactionManagerError.notPending(tx: pendingTransaction)))
                    return
                }
                
                guard !storedTx.isCancelled  else {
                    print("ignoring cancelled transaction \(storedTx)")
                    result(.failure(TransactionManagerError.cancelled(tx: storedTx)))
                    return
                }
                
                guard let raw = storedTx.raw else {
                    print("INCONSISTENCY: attempt to send pending transaction \(txId) that has not raw data")
                    result(.failure(TransactionManagerError.internalInconsistency(tx: storedTx)))
                    return
                }
                let response = try self.service.submit(spendTransaction: raw)
                
                let tx = try self.update(transaction: storedTx, on: response)
                guard response.errorCode >= 0 else {
                    result(.failure(TransactionManagerError.submitFailed(tx: tx, errorCode: Int(response.errorCode))))
                    return
                }
                
                result(.success(tx))
            } catch {
                    result(.failure(error))
            }
        }
    }
    
    func applyMinedHeight(pendingTransaction: PendingTransactionEntity, minedHeight: BlockHeight) throws -> PendingTransactionEntity {
        
        guard let id = pendingTransaction.id else {
            throw TransactionManagerError.internalInconsistency(tx: pendingTransaction)
        }
        
        guard var tx = try repository.find(by: id) else {
            throw TransactionManagerError.notPending(tx: pendingTransaction)
        }
        
        tx.minedHeight = minedHeight
        
        do {
            try repository.update(tx)
        } catch {
            throw TransactionManagerError.updateFailed(tx: tx)
        }
        return tx
    }
    
    func monitorChanges(byId: Int, observer: Any) {
        // TODO: Implement this
    }
    
    func cancel(pendingTransaction: PendingTransactionEntity) -> Bool {
        guard let id = pendingTransaction.id else { return false }
        
        guard let tx = try? repository.find(by: id) else { return false }
        
        guard !tx.isSubmitted else { return false }
        
        guard (try? repository.cancel(tx)) != nil else { return false }
        return true
    }
    
    func allPendingTransactions() throws -> [PendingTransactionEntity]? {
        try repository.getAll()
    }
    
    // MARK: other functions
    private func updateOnFailure(tx: PendingTransactionEntity, error: Error) throws {
        var pending = tx
        pending.errorMessage = error.localizedDescription
        pending.encodeAttempts = tx.encodeAttempts + 1
        try self.repository.update(pending)
    }
    
    private func update(transaction: PendingTransactionEntity, on sendResponse: LightWalletServiceResponse) throws -> PendingTransactionEntity {
        var tx = transaction
        
        let error = sendResponse.errorCode < 0
        tx.errorCode = Int(sendResponse.errorCode)
        tx.errorMessage = error ? sendResponse.errorMessage : nil
        try repository.update(tx)
        return tx
    }
}

class OutboundTransactionManagerBuilder {
    
    static func build(initializer: Initializer) -> OutboundTransactionManager {
        PersistentTransactionManager(encoder: TransactionEncoderbuilder.build(initializer: initializer), service: LightWalletGRPCService(endpoint: initializer.endpoint), repository: PendingTransactionRepositoryBuilder.build(initializer: initializer))
    }
}

class PendingTransactionRepositoryBuilder {
    static func build(initializer: Initializer) -> PendingTransactionRepository {
        PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.pendingDbURL.path, readonly: false))
    }
}

class TransactionRepositoryBuilder {
    static func build(initializer: Initializer) -> TransactionRepository {
        TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path, readonly: true))
    }
}

class TransactionEncoderbuilder {
    static func build(initializer: Initializer) -> TransactionEncoder {
        WalletTransactionEncoder(rust: initializer.rustBackend, repository:  TransactionRepositoryBuilder.build(initializer: initializer), initializer: initializer)
    }
}
