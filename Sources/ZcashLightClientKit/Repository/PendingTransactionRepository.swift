//
//  PendingTransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation

protocol PendingTransactionRepository {
    func create(_ transaction: PendingTransactionEntity) throws -> Int
    func update(_ transaction: PendingTransactionEntity) throws
    func delete(_ transaction: PendingTransactionEntity) throws
    func cancel(_ transaction: PendingTransactionEntity) throws
    func find(by id: Int) throws -> PendingTransactionEntity?
    func getAll() throws -> [PendingTransactionEntity]
    
    func applyMinedHeight(_ height: BlockHeight, id: Int) throws
}
