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
    func initSpend(zatoshi: Int, toAddress: String, memo: String?, from accountIndex: Int) throws -> PendingTransactionEntity

    func encodeShieldingTransaction(spendingKey: String, tsk: String, pendingTransaction: PendingTransactionEntity, result: @escaping (Result<PendingTransactionEntity, Error>) -> Void)
    
    func encode(spendingKey: String, pendingTransaction: PendingTransactionEntity, result: @escaping (Result<PendingTransactionEntity, Error>) -> Void)
    
    func submit(pendingTransaction: PendingTransactionEntity, result: @escaping (Result<PendingTransactionEntity, Error>) -> Void)
    
    func applyMinedHeight(pendingTransaction: PendingTransactionEntity, minedHeight: BlockHeight) throws -> PendingTransactionEntity
    
    func monitorChanges(byId: Int, observer: Any) // check this out. code smell
    
    /**
    Attempts to Cancel a transaction. Returns true if successful
     */
    func cancel(pendingTransaction: PendingTransactionEntity) -> Bool
    
    func allPendingTransactions() throws -> [PendingTransactionEntity]?
    
    func handleReorg(at: BlockHeight) throws
    
    /**
        deletes a pending transaction from the database
     */
    func delete(pendingTransaction: PendingTransactionEntity) throws
}
