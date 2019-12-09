//
//  TransactionRepositoryBuilder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/19.
//

import Foundation

class TransactionRepositoryBuilder {
    static func build(initializer: Initializer) -> TransactionRepository {
        TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path, readonly: true))
    }
}

enum TransactionKind {
    case sent
    case received
    case all
}

class PagedTransactionRepositoryBuilder {
    
    static func build(initializer: Initializer, kind: TransactionKind = .all) -> PagedTransactionRepository {
        let txRepository = TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path, readonly: true))
    return PagedTransactionDAO(repository: txRepository)
    }
}
