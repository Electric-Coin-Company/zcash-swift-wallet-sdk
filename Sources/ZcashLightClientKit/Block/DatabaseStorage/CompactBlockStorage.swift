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
}

class CompactBlockStorage: CompactBlockDAO {
    private enum TableColums {
        static let height = Expression<Int64>("height")
        static let data = Expression<Blob>("data")
    }

    private let table = Table("compactblocks")

    var dbProvider: ConnectionProvider
    
    init(connectionProvider: ConnectionProvider) {
        dbProvider = connectionProvider
    }

    func createTable() throws {
        do {
            let compactBlocks = table
            let height = TableColums.height
            let data = TableColums.data
            
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
        try dbProvider.connection().run(table.insert(block))
    }
    
    func insert(_ blocks: [ZcashCompactBlock]) throws {
        let db = try dbProvider.connection()
        try db.transaction(.immediate) {
            for block in blocks {
                try db.run(table.insert(block))
            }
        }
    }
    
    func deleteCachedBlocks(_ range: CompactBlockRange, keepCountOfLatestBlocks: Int) async throws {
        let task = Task(priority: .userInitiated) {
            let maxBlockHeightToKeep = range.upperBound - keepCountOfLatestBlocks
            guard maxBlockHeightToKeep > 0 else { return }

            let blocksDelete = table.filter(TableColums.height < Int64(maxBlockHeightToKeep))
            try dbProvider.connection().run(blocksDelete.delete())
        }
        try await task.value
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        guard let maxHeight = try dbProvider.connection().scalar(table.select(TableColums.height.max)) else {
            return BlockHeight.empty()
        }
        
        guard let blockHeight = BlockHeight(exactly: maxHeight) else {
            throw StorageError.operationFailed
        }
        
        return blockHeight
    }
    
    func rewind(to height: BlockHeight) throws {
        try dbProvider.connection().run(table.filter(TableColums.height >= Int64(height)).delete())
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
