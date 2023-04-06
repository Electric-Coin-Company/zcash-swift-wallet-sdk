//
//  TransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

typealias TransactionEncoderResultBlock = (_ result: Result<EncodedTransaction, Error>) -> Void

public enum TransactionEncoderError: Error {
    case notFound(transactionId: Int)
    case notEncoded(transactionId: Int)
    case missingParams
    case spendingKeyWrongNetwork
    case couldNotExpand(txId: Data)
}

protocol TransactionEncoder {
    /// Creates a transaction, throwing an exception whenever things are missing. When the provided wallet implementation
    /// doesn't throw an exception, we wrap the issue into a descriptive exception ourselves (rather than using
    /// double-bangs for things).
    ///
    /// - Parameters:
    /// - Parameter spendingKey: a `UnifiedSpendingKey` containing the spending key
    /// - Parameter zatoshi: the amount to send in `Zatoshi`
    /// - Parameter to: string containing the recipient address
    /// - Parameter MemoBytes: string containing the memo (optional)
    /// - Parameter accountIndex: index of the account that will be used to send the funds
    func createTransaction(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview
    
    /// Creates a transaction that will attempt to shield transparent funds that are present on the blocks cache .throwing
    /// an exception whenever things are missing. When the provided wallet implementation doesn't throw an exception,
    /// we wrap the issue into a descriptive exception ourselves (rather than using double-bangs for things).
    ///
    /// - Parameters:
    /// - Parameter spendingKey: `UnifiedSpendingKey` to spend the UTXOs
    /// - Parameter memoBytes: containing the memo (optional)
    /// - Parameter accountIndex: index of the account that will be used to send the funds
    /// - Throws: a TransactionEncoderError
    func createShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview
}
