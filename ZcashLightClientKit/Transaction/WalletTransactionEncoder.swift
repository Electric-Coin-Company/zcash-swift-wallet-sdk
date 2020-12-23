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
    var queue: DispatchQueue
    private var outputParamsURL: URL
    private var spendParamsURL: URL
    private var dataDbURL: URL
    private var cacheDbURL: URL
    
    init(rust: ZcashRustBackendWelding.Type,
         dataDb: URL,
         cacheDb: URL,
         repository: TransactionRepository,
         outputParams: URL,
         spendParams: URL) {
        
        self.rustBackend = rust
        self.dataDbURL = dataDb
        self.cacheDbURL = cacheDb
        self.repository = repository
        self.outputParamsURL = outputParams
        self.spendParamsURL = spendParams
        self.queue = DispatchQueue(label: "wallet.transaction.encoder.serial.queue")
        
    }
    
    convenience init(initializer: Initializer) {
        self.init(rust: initializer.rustBackend,
                  dataDb: initializer.dataDbURL,
                  cacheDb: initializer.cacheDbURL,
                  repository: initializer.transactionRepository,
                  outputParams: initializer.outputParamsURL,
                  spendParams: initializer.spendParamsURL)
        
    }
    
    func createTransaction(spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction {
        
        let txId = try createSpend(spendingKey: spendingKey, zatoshi: zatoshi, to: to, memo: memo, from: accountIndex)
        
        do {
            let transaction = try repository.findBy(id: txId)
            
            guard let tx = transaction else {
                throw TransactionEncoderError.notFound(transactionId: txId)
            }
            
            LoggerProxy.debug("sentTransaction id: \(txId)")
            return EncodedTransaction(transactionId: tx.transactionId , raw: tx.raw)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }
    
    func createTransaction(spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock) {
        
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                result(.success(try self.createTransaction(spendingKey: spendingKey, zatoshi: zatoshi, to: to, memo: memo, from: accountIndex)))
            } catch {
                result(.failure(error))
            }
        } 
    }
    
    func createSpend(spendingKey: String, zatoshi: Int, to address: String, memo: String?, from accountIndex: Int) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.spendParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
        
        let scannedHeight = try repository.lastScannedHeight()
        guard let latestHeight = Int32(exactly: scannedHeight) else {
            throw RustWeldingError.genericError(message: "could not convert \(scannedHeight)")
        }
        
        let consensusBranchId = try rustBackend.consensusBranchIdFor(height: latestHeight)
                
        let txId = rustBackend.createToAddress(dbData: self.dataDbURL,
                                               account: Int32(accountIndex),
                                               extsk: spendingKey,
                                               consensusBranchId: consensusBranchId,
                                               to: address,
                                               value: Int64(zatoshi),
                                               memo: memo,
                                               spendParamsPath: self.spendParamsURL.path,
                                               outputParamsPath: self.outputParamsURL.path)
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return Int(txId)
    }
    
    func createShieldingTransaction(spendingKey: String, tSecretKey: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction {
        let txId = try createShieldingSpend(spendingKey: spendingKey, tsk: tSecretKey, memo: memo, accountIndex: accountIndex)
        
        do {
            let transaction = try repository.findBy(id: txId)
            
            guard let tx = transaction else {
                throw TransactionEncoderError.notFound(transactionId: txId)
            }
            
            LoggerProxy.debug("sentTransaction id: \(txId)")
            return EncodedTransaction(transactionId: tx.transactionId , raw: tx.raw)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }
    
    func createShieldingTransaction(spendingKey: String, tSecretKey: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock) {
        queue.async {
            result(.failure(RustWeldingError.genericError(message: "not implemented")))
        }
    }
    
    func createShieldingSpend(spendingKey: String, tsk: String, memo: String?, accountIndex: Int) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.spendParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
        
        let txId = rustBackend.shieldFunds(dbCache: self.cacheDbURL,
                                           dbData: self.dataDbURL,
                                           account: Int32(accountIndex),
                                           tsk: tsk,
                                           extsk: spendingKey,
                                           memo: memo,
                                           spendParamsPath: self.spendParamsURL.path,
                                           outputParamsPath: self.outputParamsURL.path)
        
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
        guard let t = try? repository.findBy(rawId: encodedTransaction.transactionId) else {
            throw TransactionEncoderError.couldNotExpand(txId: encodedTransaction.transactionId)
        }
        return t
    }
}
