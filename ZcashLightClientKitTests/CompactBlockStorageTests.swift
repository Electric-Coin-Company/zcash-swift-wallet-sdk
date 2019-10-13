//
//  CompactBlockStorageTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import XCTest
@testable import ZcashLightClientKit
class CompactBlockStorageTests: XCTestCase {
    
    
    var storage: Storage = try! TestDbBuilder.inMemory()
    
    func testEmptyStorage() {
        XCTAssertEqual(try! storage.compactBlockDao.latestBlockHeight(), BlockHeight.empty())
    }
    
    func testStoreThousandBlocks() {
        let initialHeight = try! storage.compactBlockDao.latestBlockHeight()
        let startHeight = SAPLING_ACTIVATION_HEIGHT
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try TestDbBuilder.seed(db: storage, with: CompactBlockRange(startHeight...finalHeight))
        } catch {
            XCTFail("seed faild with error: \(error)")
            return
        }
        
        let latestHeight = try! storage.compactBlockDao.latestBlockHeight()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
        
    }
    
    func testStoreOneBlockFromEmpty() {
        
        let initialHeight = try! storage.compactBlockDao.latestBlockHeight()
        guard initialHeight == BlockHeight.empty() else {
            XCTFail("database not empty, latest height: \(initialHeight)")
            return
        }
        
        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create randem block with height: \(expectedHeight)")
            return
        }
        XCTAssertNoThrow(try storage.compactBlockDao.insert(block))
        
        do {
            let result = try storage.compactBlockDao.latestBlockHeight()
            XCTAssertEqual(result, expectedHeight)
        } catch {
            XCTFail("latestBlockHeight failed")
            return
        }
    }
    
    
    func testRewindTo() {
        
        let startHeight = SAPLING_ACTIVATION_HEIGHT
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try TestDbBuilder.seed(db: storage, with: CompactBlockRange(startHeight...finalHeight))
        } catch {
            XCTFail("seed faild with error: \(error)")
            return
        }
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        XCTAssertNoThrow(try storage.compactBlockDao.rewind(to: rewindHeight))
        do {
            let latestHeight = try storage.compactBlockDao.latestBlockHeight()
            XCTAssertEqual(latestHeight, rewindHeight - 1)
            
        } catch {
            XCTFail("Rewind latest block failed with error: \(error)")
        }
        
    }
}



import SQLite
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
