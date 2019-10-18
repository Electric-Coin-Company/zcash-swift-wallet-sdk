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
    
    var db: Connection
    var table: Table
    var height = Expression<Int>("height")
    
    init(dataDb: URL) throws {
        self.db = try Connection(dataDb.absoluteString, readonly: true)
        self.table = Table("Blocks")
        
    }
    
    func latestBlockHeight() throws -> BlockHeight {
       try db.scalar(table.select(height.max)) ?? BlockHeight.empty()
    }
    
}

extension BlockSQLDAO: BlockRepository {
    func lastScannedBlockHeight() -> BlockHeight {
        (try? self.latestBlockHeight()) ?? BlockHeight.empty()
    }
}
