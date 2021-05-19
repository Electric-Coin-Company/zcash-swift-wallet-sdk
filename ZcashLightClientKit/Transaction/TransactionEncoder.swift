//
//  TransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

typealias TransactionEncoderResultBlock = (_ result: Result<EncodedTransaction,Error>) -> Void

public enum TransactionEncoderError: Error {
    case notFound(transactionId: Int)
    case NotEncoded(transactionId: Int)
    case missingParams
    case spendingKeyWrongNetwork
    case couldNotExpand(txId: Data)
}

protocol TransactionEncoder {
    
    /**
    Creates a transaction, throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Blocking
     
     - Parameters:
     - Parameter spendingKey: a string containing the spending key
     - Parameter zatoshi: the amount to send in zatoshis
     - Parameter to: string containing the recipient address
     - Parameter memo: string containing the memo (optional)
     - Parameter accountIndex: index of the account that will be used to send the funds
     
     - Throws: a TransactionEncoderError
    */
    func createTransaction(spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction
    
    /**
    Creates a transaction, throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Non-blocking
     
     - Parameters:
    - Parameter spendingKey: a string containing the spending key
    - Parameter zatoshi: the amount to send in zatoshis
    - Parameter to: string containing the recipient address
    - Parameter memo: string containing the memo (optional)
    - Parameter accountIndex: index of the account that will be used to send the funds
    - Parameter result: a non escaping closure that receives a Result containing either an EncodedTransaction or a TransactionEncoderError
    */
    func createTransaction(spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock)
    
    /**
    Creates a transaction that will attempt to shield transparent funds that are present on the cacheDB .throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Blocking
     
     - Parameters:
     - Parameter spendingKey: a string containing the spending key
     - Parameter tSecretKey: transparent secret key to spend the UTXOs
     - Parameter memo: string containing the memo (optional)
     - Parameter accountIndex: index of the account that will be used to send the funds
     
     - Throws: a TransactionEncoderError
    */
    func createShieldingTransaction(spendingKey: String, tSecretKey: String, memo: String?, from accountIndex: Int) throws -> EncodedTransaction
    
    /**
    Creates a transaction that will attempt to shield transparent funds that are present on the cacheDB .throwing an exception whenever things are missing. When the provided wallet implementation
    doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    double-bangs for things).
     Non-Blocking
     
     - Parameters:
     - Parameter spendingKey: a string containing the spending key
     - Parameter tSecretKey: transparent secret key to spend the UTXOs
     - Parameter memo: string containing the memo (optional)
     - Parameter accountIndex: index of the account that will be used to send the funds
     
     - Returns: a TransactionEncoderResultBlock
    */
    
    func createShieldingTransaction(spendingKey: String, tSecretKey: String, memo: String?, from accountIndex: Int, result: @escaping TransactionEncoderResultBlock)
    
    /**
        Fetch the Transaction Entity from the encoded representation
     - Parameter encodedTransaction: The encoded transaction to expand
     - Returns: a TransactionEntity based on the given Encoded Transaction
     - Throws: a TransactionEncoderError
     */
    func expandEncodedTransaction(_ encodedTransaction: EncodedTransaction) throws -> TransactionEntity
}
