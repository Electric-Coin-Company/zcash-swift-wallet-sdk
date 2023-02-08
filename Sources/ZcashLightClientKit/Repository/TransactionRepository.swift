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
    case transactionMissingRequiredFields
}

protocol TransactionRepository {
    func closeDBConnection()
    func countAll() throws -> Int
    func countUnmined() throws -> Int
    func blockForHeight(_ height: BlockHeight) throws -> Block?
    func lastScannedHeight() throws -> BlockHeight
    func isInitialized() throws -> Bool
    func find(id: Int) throws -> ZcashTransaction.Overview
    func find(rawID: Data) throws -> ZcashTransaction.Overview
    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [ZcashTransaction.Overview]
    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) throws -> [ZcashTransaction.Overview]
    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) throws -> [ZcashTransaction.Overview]
    func findReceived(offset: Int, limit: Int) throws -> [ZcashTransaction.Received]
    func findSent(offset: Int, limit: Int) throws -> [ZcashTransaction.Sent]
    func findMemos(for transaction: ZcashTransaction.Overview) throws -> [Memo]
    func findMemos(for receivedTransaction: ZcashTransaction.Received) throws -> [Memo]
    func findMemos(for sentTransaction: ZcashTransaction.Sent) throws -> [Memo]
    func getRecipients(for id: Int) -> [TransactionRecipient]
}
