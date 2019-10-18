//
//  TestDbBuilder.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/14/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite
@testable import ZcashLightClientKit

struct TestDbBuilder {
    
    enum TestBuilderError: Error {
        case generalError
    }
    
    static func inMemory() throws -> Storage {
        
        let connection = try Connection(.inMemory, readonly: false)
        let compactBlockDao = CompactBlockStorage(connection: connection)
        try compactBlockDao.createTable()
        
        return SQLiteStorage(connection: connection, compactBlockDAO: compactBlockDao)
        
    }
    
    static func inMemoryCompactBlockStorage() throws -> CompactBlockStorage {
        let connection = try Connection(.inMemory, readonly: false)
        let compactBlockDao = CompactBlockStorage(connection: connection)
        try compactBlockDao.createTable()
        return compactBlockDao
    }
    
    static func diskCompactBlockStorage(at url: URL) throws -> CompactBlockStorage {
        let connection = try Connection(url.absoluteString)
        let compactBlockDao = CompactBlockStorage(connection: connection)
        try compactBlockDao.createTable()
        return compactBlockDao
    }
        
    static func seed(db: Storage, with blockRange: CompactBlockRange) throws {
        
        guard let blocks = StubBlockCreator.createBlockRange(blockRange) else {
            throw TestBuilderError.generalError
        }
        
        try db.compactBlockDao.insert(blocks)
    }
}

struct StubBlockCreator {
    static func createRandomDataBlock(with height: BlockHeight) -> ZcashCompactBlock? {
        guard let data = randomData(ofLength: 100) else {
            print("error creating stub block")
            return nil
        }
        return ZcashCompactBlock(height: height, data: data)
    }
    static func createBlockRange(_ range: CompactBlockRange) -> [ZcashCompactBlock]? {
        
        var blocks = [ZcashCompactBlock]()
        for height in range {
            guard let block = createRandomDataBlock(with: height) else {
                return nil
            }
            blocks.append(block)
        }
        
        return blocks
    }
    
    static func randomData(ofLength length: Int) -> Data? {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status == errSecSuccess {
            return Data(bytes: &bytes, count: bytes.count)
        }
        print("Status \(status)")
        return nil
        
    }
    
}
