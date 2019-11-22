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
    
    init(rust: ZcashRustBackend.Type, repository: TransactionRepository) {
        self.rustBackend = rust
        self.repository = repository
    }
    
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: Data?, from accountIndex: Int) throws -> EncodedTransaction {
        throw TransactionEncoderError.missingParams
    }
    
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: Data?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                result(.success(try self.createTransaction(spendingKey: spendingKey, zatoshi: zatoshi, to: to, memo: memo, from: accountIndex)))
            } catch {
                result(.failure(error))
            }
        } 
    }
    
    func createSpend(spendingKey: String, zatoshi: Int, to address: String, memo: Data?, from accountIndex: Int) -> Int64 {
        return -1
    }
    
    func ensureParams(destination: URL) -> Bool {
        return false
    }
}
