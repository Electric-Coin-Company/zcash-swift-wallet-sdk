//
//  BlockDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

protocol BlockDao {
    func latestBlockHeight() throws -> BlockHeight
}

class BlockSQLDAO: BlockDao {
    
    var dbProvider: ConnectionProvider
    var table: Table
    var height = Expression<Int>("height")
    
    init(dbProvider: ConnectionProvider) throws {
        self.dbProvider = dbProvider
        self.table = Table("Blocks")
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        try dbProvider.connection().scalar(table.select(height.max)) ?? BlockHeight.empty()
    }
}

extension BlockSQLDAO: BlockRepository {
    func lastScannedBlockHeight() -> BlockHeight {
        (try? self.latestBlockHeight()) ?? BlockHeight.empty()
    }
}
