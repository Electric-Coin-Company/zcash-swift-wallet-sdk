//
//  TransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/16/19.
//

import Foundation

enum TransactionRepositoryError: Error {
    case malformedTransaction
    case notFound
}

protocol TransactionRepository {
    func countAll() throws -> Int
    func countUnmined() throws -> Int
    func blockForHeight(_ height: BlockHeight) throws -> Block?
    func findAll(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func findAll(from: ConfirmedTransactionEntity?, limit: Int) throws -> [ConfirmedTransactionEntity]?
    func lastScannedHeight() throws -> BlockHeight
    func isInitialized() throws -> Bool

    // MARK: - TransactionNG methods

    func find(id: Int) throws -> TransactionNG.Overview
    func find(rawID: Data) throws -> TransactionNG.Overview
    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview]
    func find(in range: BlockRange, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview]
    func find(from: TransactionNG.Overview, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview]
    func findReceived(offset: Int, limit: Int) throws -> [TransactionNG.Received]
    func findSent(offset: Int, limit: Int) throws -> [TransactionNG.Sent]
    func findSent(in range: BlockRange, limit: Int) throws -> [TransactionNG.Sent]
    func findSent(rawID: Data) throws -> TransactionNG.Sent
}
