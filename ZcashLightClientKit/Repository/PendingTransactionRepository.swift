//
//  PendingTransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation

protocol PendingTransactionRepository {
    func create(_ transaction: PendingTransactionEntity) throws -> Int64
    func update(_ transaction: PendingTransactionEntity) throws
    func delete(_ transaction: PendingTransactionEntity) throws
    func cancel(_ transaction: PendingTransactionEntity) throws
    func find(by id: Int64) throws -> PendingTransactionEntity?
    func getAll() throws -> [PendingTransactionEntity]
}
