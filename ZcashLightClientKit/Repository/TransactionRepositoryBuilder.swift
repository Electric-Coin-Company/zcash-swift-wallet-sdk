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

class PagedTransactionRepositoryBuilder {
    
    static func build(initializer: Initializer, kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        let txRepository = TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path, readonly: true))
        return PagedTransactionDAO(repository: txRepository, kind: kind)
    }
}
