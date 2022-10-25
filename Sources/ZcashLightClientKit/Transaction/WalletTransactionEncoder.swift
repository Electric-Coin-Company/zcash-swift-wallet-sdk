//
//  WalletTransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

class WalletTransactionEncoder: TransactionEncoder {
    var rustBackend: ZcashRustBackendWelding.Type
    var repository: TransactionRepository

    private var outputParamsURL: URL
    private var spendParamsURL: URL
    private var dataDbURL: URL
    private var cacheDbURL: URL
    private var networkType: NetworkType
    
    init(
        rust: ZcashRustBackendWelding.Type,
        dataDb: URL,
        cacheDb: URL,
        repository: TransactionRepository,
        outputParams: URL,
        spendParams: URL,
        networkType: NetworkType
    ) {
        self.rustBackend = rust
        self.dataDbURL = dataDb
        self.cacheDbURL = cacheDb
        self.repository = repository
        self.outputParamsURL = outputParams
        self.spendParamsURL = spendParams
        self.networkType = networkType
    }
    
    convenience init(initializer: Initializer) {
        self.init(
            rust: initializer.rustBackend,
            dataDb: initializer.dataDbURL,
            cacheDb: initializer.cacheDbURL,
            repository: initializer.transactionRepository,
            outputParams: initializer.outputParamsURL,
            spendParams: initializer.spendParamsURL,
            networkType: initializer.network.networkType
        )
    }
    
    func createTransaction(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> EncodedTransaction {
        let txId = try createSpend(
            spendingKey: spendingKey,
            zatoshi: zatoshi,
            to: address,
            memoBytes: memoBytes,
            from: accountIndex
        )
        
        do {
            let transactionEntity = try repository.findBy(id: txId)
            guard let transaction = transactionEntity else {
                throw TransactionEncoderError.notFound(transactionId: txId)
            }

            LoggerProxy.debug("sentTransaction id: \(txId)")

            return EncodedTransaction(transactionId: transaction.transactionId, raw: transaction.raw)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }
    
    func createSpend(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.spendParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
                
        let txId = rustBackend.createToAddress(
            dbData: self.dataDbURL,
            usk: spendingKey,
            to: address,
            value: zatoshi.amount,
            memo: memoBytes,
            spendParamsPath: self.spendParamsURL.path,
            outputParamsPath: self.outputParamsURL.path,
            networkType: networkType
        )
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return Int(txId)
    }
    
    func createShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> EncodedTransaction {
        let txId = try createShieldingSpend(
            spendingKey: spendingKey,
            memo: memoBytes,
            accountIndex: accountIndex
        )
        
        do {
            let transactionEntity = try repository.findBy(id: txId)
            
            guard let transaction = transactionEntity else {
                throw TransactionEncoderError.notFound(transactionId: txId)
            }
            
            LoggerProxy.debug("sentTransaction id: \(txId)")
            return EncodedTransaction(transactionId: transaction.transactionId, raw: transaction.raw)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }
    func createShieldingSpend(
        spendingKey: UnifiedSpendingKey,
        memo: MemoBytes?,
        accountIndex: Int
    ) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.spendParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
        
        let txId = rustBackend.shieldFunds(
            dbCache: self.cacheDbURL,
            dbData: self.dataDbURL,
            usk: spendingKey,
            memo: memo,
            spendParamsPath: self.spendParamsURL.path,
            outputParamsPath: self.outputParamsURL.path,
            networkType: networkType
        )
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return Int(txId)
    }
    
    func ensureParams(spend: URL, output: URL) -> Bool {
        let readableSpend = FileManager.default.isReadableFile(atPath: spend.path)
        let readableOutput = FileManager.default.isReadableFile(atPath: output.path)
        
        return readableSpend && readableOutput // Todo: change this to something that makes sense
    }
    
    /**
    Fetch the Transaction Entity from the encoded representation
    - Parameter encodedTransaction: The encoded transaction to expand
    - Returns: a TransactionEntity based on the given Encoded Transaction
    - Throws: a TransactionEncoderError
    */
    func expandEncodedTransaction(_ encodedTransaction: EncodedTransaction) throws -> TransactionEntity {
        guard let transaction = try? repository.findBy(rawId: encodedTransaction.transactionId) else {
            throw TransactionEncoderError.couldNotExpand(txId: encodedTransaction.transactionId)
        }
        return transaction
    }
}
