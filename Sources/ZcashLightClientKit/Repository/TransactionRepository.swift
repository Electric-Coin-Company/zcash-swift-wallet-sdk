//
//  TransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/16/19.
//

import Foundation

protocol TransactionRepository {
    func closeDBConnection()
    /// count all transactions
    func countAll() async throws -> Int
    /// count all transactions that haven't been mined
    func countUnmined() async throws -> Int
    /// gets the block information for the given height
    /// - parameter height: blockheight for the given block
    func blockForHeight(_ height: BlockHeight) async throws -> Block?
    /// last scanned height for this wallet.
    func lastScannedHeight() async throws -> BlockHeight
    /// last scanned block for this wallet
    func lastScannedBlock() async throws -> Block?
    /// find transaction by internal ID in the database
    /// - parameter id: internal id of the transaction in this database instance
    func find(id: Int) async throws -> ZcashTransaction.Overview
    /// find transaction by transaction Id in the network
    /// - parameter rawID: transaction id of the transaction found in the blockchain
    func find(rawID: Data) async throws -> ZcashTransaction.Overview
    /// find transactions by `TransactionKind`
    /// - parameter offset: offset of the query (used for paging results)
    /// - parameter limit: limit for number of rows to be returned
    /// - parameter kind: `TransactionKind` of the query
    /// - Returns transactions found or empty array if none.
    func find(offset: Int, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    /// find transactions for a given `CompactBlockRange`
    /// - parameter range: the range
    /// - parameter limit: limit for number of rows to be returned
    /// - parameter kind: `TransactionKind` of the query
    /// - Returns transactions found or empty array if none.
    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    /// find transactions from a given transaction onwards
    /// - parameter from: the transaction known by caller to use in the query
    /// - parameter limit: limit for number of rows to be returned
    /// - parameter kind: `TransactionKind` of the query
    /// - Returns transactions found or empty array if none.
    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview]
    /// find pending transactions (of any kind) in relation from a given latest height
    /// - parameter latestHeight: given latest height
    /// - parameter offset: offset of the query (used for paging results)
    /// - parameter limit: limit for number of rows to be returned
    /// - Returns transactions found or empty array if none.
    func findPendingTransactions(latestHeight: BlockHeight, offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    /// find inbound transaction for the keys being tracked on this wallet
    /// - parameter offset: offset of the query (used for paging results)
    /// - parameter limit: limit for number of rows to be returned
    /// - Returns transactions found or empty array if none.
    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    /// find outbound transaction for the keys being tracked on this wallet
    /// - parameter offset: offset of the query (used for paging results)
    /// - parameter limit: limit for number of rows to be returned
    /// - Returns transactions found or empty array if none.
    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview]
    /// find memos for a given transaction
    /// - parameter transaction: the transaction of interest to get the memos for
    /// - returns an array of `Memo`
    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo]
    /// gets the recipients for a given (internal) transaction Id
    /// - parameter id: internal transaction id
    /// - returns array of recipients
    func getRecipients(for id: Int) async throws -> [TransactionRecipient]
    /// gets the transaction outputs known to this wallet for the given transactions
    /// - parameter id: internal transaction id
    /// - Returns transactions found or empty array if none.
    func getTransactionOutputs(for id: Int) async throws -> [ZcashTransaction.Output]
    /// gets the last transaction that was fully downloaded and decrypted.
    /// - Note: if you are useing this to establish a last completed range, this doesn't mean that there
    /// could be others that hadn't been downloaded and decrypted. For that you can get the
    /// `unenhancedTransactions` functions
    func firstUnenhancedTransaction() async throws -> ZcashTransaction.Output?
    /// get all the transactions that haven't been downloaded and decrypted.
    /// - Note: we use the `raw` field of the database to consider if the raw data has been downloaded
    /// - Returns transactions found or empty array if none.
    func unenhancedTransactions() async throws -> [ZcashTransaction.Output]
}
