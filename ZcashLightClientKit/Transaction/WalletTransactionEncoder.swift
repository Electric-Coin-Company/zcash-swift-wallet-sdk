//
//  WalletTransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

class WalletTransactionEncoder: TransactionEncoder {
    var rustBackend: ZcashRustBackend.Type
    var repository: TransactionRepository
    var initializer: Initializer
    init(rust: ZcashRustBackend.Type, repository: TransactionRepository, initializer: Initializer) {
        self.rustBackend = rust
        self.repository = repository
        self.initializer = initializer
    }
    
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction {
        
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
    
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                result(.success(try self.createTransaction(spendingKey: spendingKey, zatoshi: zatoshi, to: to, memo: memo, from: accountIndex)))
            } catch {
                result(.failure(error))
            }
        } 
    }
    
    func createSpend(spendingKey: String, zatoshi: Int64, to address: String, memo: String?, from accountIndex: Int) throws -> Int64 {
        guard ensureParams(spend: initializer.spendParamsURL, output: initializer.spendParamsURL),
            let spend = URL(string: initializer.spendParamsURL.path), let output = URL(string: initializer.outputParamsURL.path) else {
            throw TransactionEncoderError.missingParams
        }
        
        
        let txId = rustBackend.sendToAddress(dbData: initializer.dataDbURL, account: Int32(accountIndex), extsk: spendingKey, to: address, value: Int64(zatoshi), memo: memo, spendParams: spend, outputParams: output)
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return txId
    }
    
    func ensureParams(spend: URL, output: URL) -> Bool {
        
        let readableSpend = FileManager.default.isReadableFile(atPath: spend.path)
        let readableOutput = FileManager.default.isReadableFile(atPath: output.path)
        
        return readableSpend && readableOutput // Todo: change this to something that makes sense
    }
}
