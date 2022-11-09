//
//  TransactionManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/26/19.
//

import Foundation

/**
Manage outbound transactions with the main purpose of reporting which ones are still pending,
particularly after failed attempts or dropped connectivity. The intent is to help see outbound
transactions through to completion.
*/

protocol OutboundTransactionManager {
    func initSpend(
        zatoshi: Zatoshi,
        recipient: PendingTransactionRecipient,
        memo: MemoBytes?,
        from accountIndex: Int
    ) throws -> PendingTransactionEntity

    func encodeShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity
    
    func encode(
        spendingKey: UnifiedSpendingKey,
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity
    
    func submit(
        pendingTransaction: PendingTransactionEntity
    ) async throws -> PendingTransactionEntity
    
    func applyMinedHeight(
        pendingTransaction: PendingTransactionEntity,
        minedHeight: BlockHeight
    ) throws -> PendingTransactionEntity
    
    /**
    Attempts to Cancel a transaction. Returns true if successful
    */
    func cancel(pendingTransaction: PendingTransactionEntity) -> Bool
    
    func allPendingTransactions() throws -> [PendingTransactionEntity]?
    
    func handleReorg(at blockHeight: BlockHeight) throws
    
    /**
    Deletes a pending transaction from the database
    */
    func delete(pendingTransaction: PendingTransactionEntity) throws
}
