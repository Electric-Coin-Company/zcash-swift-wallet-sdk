//
//  TransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/16/19.
//

import Foundation

protocol TransactionRepository {
    func closeDBConnection()
    func countAll() async throws -> Int
    func countUnmined() async throws -> Int
    func blockForHeight(_ height: BlockHeight) async throws -> Block?
    func lastScannedHeight() async throws -> BlockHeight
    func lastScannedBlock() async throws -> Block?
    func isInitialized() async throws -> Bool
    func find(id: Int) async throws -> ZcashTransaction.Overview
    func find(rawID: Data) async throws -> ZcashTransaction.Overview
    func find(offset: Int, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    func findPendingTransactions(latestHeight: BlockHeight, offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo]
    func getRecipients(for id: Int) async throws -> [TransactionRecipient]
    func getTransactionOutputs(for id: Int) async throws -> [ZcashTransaction.Output]
}
