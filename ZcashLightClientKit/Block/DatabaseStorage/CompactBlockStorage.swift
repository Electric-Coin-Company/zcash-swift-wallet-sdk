//
//  CompactBlockStorage.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite
struct CompactBlockStorage: CompactBlockDAO {
    var db: Connection
    
    init(connection: Connection) {
        self.db = connection
    }
    
    func createTable() throws {
        do {
            let compactBlocks = Table("compactblocks")
            let height = Expression<Int64>("height")
            let data = Expression<Blob>("data")
            
            try db.run(compactBlocks.create(ifNotExists: true) { t in
                t.column(height, primaryKey: true)
                t.column(data)
            } )
        } catch {
            throw StorageError.couldNotCreate
        }
    }
    
    func insert(_ block: ZcashCompactBlock) throws {
        // todo: insert block
    }
    
    func insert(_ blocks: [ZcashCompactBlock]) throws {
        // todo: insert blocks
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        // todo : get block height
        return -1
    }
    
    func rewind(to height: BlockHeight) throws {
        // todo: rewind to height
    }
    
    
}
