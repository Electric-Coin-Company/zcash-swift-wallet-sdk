//
//  TransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

typealias TransactionEncoderResultBlock = (_ result: Result<EncodedTransaction,Error>) -> Void

public enum TransactionEncoderError: Error {
    case notFound(transactionId: Int64)
    case NotEncoded(transactionId: Int64)
    case missingParams
    case spendingKeyWrongNetwork
}

protocol TransactionEncoder {
    
    /**
    Creates a transaction, throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Blocking
    */
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction
    
    /**
    Creates a transaction, throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Non-blocking
    */
    func createTransaction(spendingKey: String, zatoshi: Int64, to: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock)
    
}
