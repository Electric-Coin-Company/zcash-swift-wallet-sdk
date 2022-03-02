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
    func block(at height: BlockHeight) throws -> Block?
}

struct Block: Codable {
    enum CodingKeys: String, CodingKey {
        case height
        case hash
        case time
        case saplingTree = "sapling_tree"
    }

    enum TableStructure {
        static var height = Expression<Int>(Block.CodingKeys.height.rawValue)
        static var hash = Expression<Blob>(Block.CodingKeys.hash.rawValue)
        static var time = Expression<Int>(Block.CodingKeys.time.rawValue)
        static var saplingTree = Expression<Blob>(Block.CodingKeys.saplingTree.rawValue)
    }

    var height: BlockHeight
    var hash: Data
    var time: Int
    var saplingTree: Data
    
    static var table = Table("blocks")
}

class BlockSQLDAO: BlockDao {
    var dbProvider: ConnectionProvider
    var table: Table
    var height = Expression<Int>("height")
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
        self.table = Table("Blocks")
    }

    func block(at height: BlockHeight) throws -> Block? {
        try dbProvider
            .connection()
            .prepare(Block.table.filter(Block.TableStructure.height == height).limit(1))
            .map({ try $0.decode() })
            .first
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
