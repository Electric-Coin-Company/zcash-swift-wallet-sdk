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
//    var initializer: Initializer
    var queue: DispatchQueue
    private var outputParamsURL: URL
    private var spendParamsURL: URL
    private var dataDbURL: URL

    init(rust: ZcashRustBackendWelding.Type,
         dataDb: URL,
         repository: TransactionRepository,
         outputParams: URL,
         spendParams: URL) {
        
        self.rustBackend = rust
        self.dataDbURL = dataDb
        self.repository = repository
        self.outputParamsURL = outputParams
        self.spendParamsURL = spendParams
        self.queue = DispatchQueue(label: "wallet.transaction.encoder.serial.queue")
        
    }
    
    convenience init(initializer: Initializer) {
        self.init(rust: initializer.rustBackend,
                  dataDb: initializer.dataDbURL,
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
            
            print("sentTransaction id: \(txId)")
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
                
        let txId = rustBackend.createToAddress(dbData: self.dataDbURL, account: Int32(accountIndex), extsk: spendingKey, to: address, value: Int64(zatoshi), memo: memo, spendParamsPath: self.spendParamsURL.path, outputParamsPath: self.outputParamsURL.path)
        
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
}
