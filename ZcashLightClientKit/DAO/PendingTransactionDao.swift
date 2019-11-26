//
//  PendingTransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation

class PendingTransactionSQLDAO: PendingTransactionRepository {
    
    var dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func create(_ transaction: PendingTransactionEntity) throws -> Int64 {
        -1
    }
    
    func update(_ transaction: PendingTransactionEntity) throws {
        
    }
    
    func delete(_ transaction: PendingTransactionEntity) throws {
        
    }
    
    func cancel(_ transaction: PendingTransactionEntity) throws {
        
    }
    
    func find(by id: Int64) throws -> PendingTransactionEntity? {
        nil
    }
    
    func getAll() throws -> [PendingTransactionEntity] {
        []
    }
    
}
