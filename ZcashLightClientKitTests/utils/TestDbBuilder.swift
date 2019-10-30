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
    
    static func inMemoryCompactBlockStorage() throws -> CompactBlockStorage {
        let compactBlockDao = CompactBlockStorage(connectionProvider: InMemoryDbProvider())
        try compactBlockDao.createTable()
        return compactBlockDao
    }
    
    static func diskCompactBlockStorage(at url: URL) throws -> CompactBlockStorage {
        let compactBlockDao = CompactBlockStorage(connectionProvider: SimpleConnectionProvider(path: url.absoluteString))
        try compactBlockDao.createTable()
        return compactBlockDao
    }
        
    static func seed(db: CompactBlockStoring, with blockRange: CompactBlockRange) throws {
        
        guard let blocks = StubBlockCreator.createBlockRange(blockRange) else {
            throw TestBuilderError.generalError
        }
        
        try db.write(blocks: blocks)
    }
}

struct InMemoryDbProvider: ConnectionProvider {
    var readonly: Bool
    
    init(readonly: Bool = false) {
        self.readonly = readonly
    }
    
    func connection() throws -> Connection {
       try Connection(.inMemory, readonly: readonly)
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
