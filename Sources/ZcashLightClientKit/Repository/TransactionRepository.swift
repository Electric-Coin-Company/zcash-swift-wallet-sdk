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
    func blockForHeight(_ height: BlockHeight) throws -> Block?
    func findBy(id: Int) throws -> TransactionEntity?
    func findBy(rawId: Data) throws -> TransactionEntity?
    func findAllSentTransactions(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findAllReceivedTransactions(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findAll(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findAll(from: ConfirmedTransactionEntity?, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func lastScannedHeight() throws -> BlockHeight
    func isInitialized() throws -> Bool
    func findEncodedTransactionBy(txId: Int) -> EncodedTransaction?
    func findTransactions(in range: BlockRange, limit: Int) throws -> [TransactionEntity]?
    func findConfirmedTransactions(in range: BlockRange, offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findConfirmedTransactionBy(rawId: Data) throws -> ConfirmedTransactionEntity?
}
