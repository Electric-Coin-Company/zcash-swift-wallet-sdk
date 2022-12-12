//
//  CompactBlockStorage.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

protocol ConnectionProvider {
    func connection() throws -> Connection
    func close()
}

class CompactBlockStorage: CompactBlockDAO {
    var dbProvider: ConnectionProvider
    
    init(connectionProvider: ConnectionProvider) {
        dbProvider = connectionProvider
    }
    
    private func compactBlocksTable() -> Table {
        Table("compactblocks")
    }
    private func heightColumn() -> Expression<Int64> {
        Expression<Int64>("height")
    }
    private func dataColumn() -> Expression<Blob> {
        Expression<Blob>("data")
    }

    func closeDBConnection() {
        dbProvider.close()
    }

    func createTable() throws {
        do {
            let compactBlocks = compactBlocksTable()
            let height = heightColumn()
            let data = dataColumn()
            
            let db = try dbProvider.connection()
         
            try db.run(compactBlocks.create(ifNotExists: true) { table in
                table.column(height, primaryKey: true)
                table.column(data)
            }
            )
            
            try db.run(compactBlocks.createIndex(height, ifNotExists: true))
        } catch {
            throw StorageError.couldNotCreate
        }
    }
    
    func insert(_ block: ZcashCompactBlock) throws {
        try dbProvider.connection().run(compactBlocksTable().insert(block))
    }
    
    func insert(_ blocks: [ZcashCompactBlock]) throws {
        let compactBlocks = compactBlocksTable()
        let db = try dbProvider.connection()
        try db.transaction(.immediate) {
            for block in blocks {
                try db.run(compactBlocks.insert(block))
            }
        }
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        guard let maxHeight = try dbProvider.connection().scalar(compactBlocksTable().select(heightColumn().max)) else {
            return BlockHeight.empty()
        }
        
        guard let blockHeight = BlockHeight(exactly: maxHeight) else {
            throw StorageError.operationFailed
        }
        
        return blockHeight
    }
    
    func rewind(to height: BlockHeight) throws {
        try dbProvider.connection().run(compactBlocksTable().filter(heightColumn() >= Int64(height)).delete())
    }
}

extension CompactBlockStorage: CompactBlockRepository {
    func latestHeight() throws -> BlockHeight {
        try latestBlockHeight()
    }
    
    func latestHeightAsync() async throws -> BlockHeight {
        let task = Task(priority: .userInitiated) {
            try latestBlockHeight()
        }
        return try await task.value
    }
    
    func write(blocks: [ZcashCompactBlock]) async throws {
        let task = Task(priority: .userInitiated) {
            try insert(blocks)
        }
        try await task.value
    }

    func rewindAsync(to height: BlockHeight) async throws {
        let task = Task(priority: .userInitiated) {
            try rewind(to: height)
        }
        try await task.value
    }
}
