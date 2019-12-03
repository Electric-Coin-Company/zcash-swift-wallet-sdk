//
//  TransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/16/19.
//

import Foundation

enum TransactionRepositoryError: Error {
    case malformedTransaction
}

protocol TransactionRepository {
    func countAll() throws -> Int
    func countUnmined() throws -> Int
    func findBy(id: Int) throws -> TransactionEntity?
    func findBy(rawId: Data) throws -> TransactionEntity?
    func findAllSentTransactions(limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findAllReceivedTransactions(limit: Int) throws ->  [ConfirmedTransactionEntity]?
    func findAll(limit: Int) throws -> [ConfirmedTransactionEntity]?
}
