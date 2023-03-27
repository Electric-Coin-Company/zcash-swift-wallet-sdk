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
    func countAll() async throws -> Int
    func countUnmined() async throws -> Int
    func blockForHeight(_ height: BlockHeight) async throws -> Block?
    func lastScannedHeight() async throws -> BlockHeight
    func isInitialized() async throws -> Bool
    func find(id: Int) async throws -> ZcashTransaction.Overview
    func find(rawID: Data) async throws -> ZcashTransaction.Overview
    func find(offset: Int, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Received]
    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Sent]
    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo]
    func findMemos(for receivedTransaction: ZcashTransaction.Received) async throws -> [Memo]
    func findMemos(for sentTransaction: ZcashTransaction.Sent) async throws -> [Memo]
    func getRecipients(for id: Int) async -> [TransactionRecipient]
}
