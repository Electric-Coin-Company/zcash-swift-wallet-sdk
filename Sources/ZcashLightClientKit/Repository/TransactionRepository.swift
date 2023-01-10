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
    func closeDBConnection()
    func countAll() throws -> Int
    func countUnmined() throws -> Int
    func blockForHeight(_ height: BlockHeight) throws -> Block?
    func lastScannedHeight() throws -> BlockHeight
    func isInitialized() throws -> Bool
    func find(id: Int) throws -> Transaction.Overview
    func find(rawID: Data) throws -> Transaction.Overview
    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview]
    func find(in range: BlockRange, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview]
    func find(from: Transaction.Overview, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview]
    func findReceived(offset: Int, limit: Int) throws -> [Transaction.Received]
    func findSent(offset: Int, limit: Int) throws -> [Transaction.Sent]
    func findSent(in range: BlockRange, limit: Int) throws -> [Transaction.Sent]
    func findSent(rawID: Data) throws -> Transaction.Sent
    func findMemos(for transaction: Transaction.Overview) throws -> [Memo]
    func findMemos(for receivedTransaction: Transaction.Received) throws -> [Memo]
    func findMemos(for sentTransaction: Transaction.Sent) throws -> [Memo]
}
