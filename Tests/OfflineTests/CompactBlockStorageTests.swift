//
//  CompactBlockStorageTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
@testable import TestUtils
import XCTest

// swiftlint:disable force_try
@testable import ZcashLightClientKit
class CompactBlockStorageTests: XCTestCase {
    let network = ZcashNetworkBuilder.network(for: .testnet)
    var compactBlockDao: CompactBlockRepository = try! TestDbBuilder.inMemoryCompactBlockStorage()

    func testEmptyStorage() {
        XCTAssertEqual(try! compactBlockDao.latestHeight(), BlockHeight.empty())
    }

    func testEmptyStorageAsync() async throws {
        let latestHeight = try await compactBlockDao.latestHeightAsync()
        XCTAssertEqual(latestHeight, BlockHeight.empty())
    }

    func testStoreThousandBlocks() {
        let initialHeight = try! compactBlockDao.latestHeight()
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try TestDbBuilder.seed(db: compactBlockDao, with: startHeight...finalHeight)
        } catch {
            XCTFail("seed faild with error: \(error)")
            return
        }
        
        let latestHeight = try! compactBlockDao.latestHeight()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
    }
    
    func testStoreThousandBlocksAsync() async throws {
        let initialHeight = try! compactBlockDao.latestHeight()
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try TestDbBuilder.seed(db: compactBlockDao, with: startHeight...finalHeight)
        
        let latestHeight = try await compactBlockDao.latestHeightAsync()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
    }
    
    func testStoreOneBlockFromEmpty() {
        let initialHeight = try! compactBlockDao.latestHeight()
        guard initialHeight == BlockHeight.empty() else {
            XCTFail("database not empty, latest height: \(initialHeight)")
            return
        }
        
        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create randem block with height: \(expectedHeight)")
            return
        }
        XCTAssertNoThrow(try compactBlockDao.write(blocks: [block]))
        
        do {
            let result = try compactBlockDao.latestHeight()
            XCTAssertEqual(result, expectedHeight)
        } catch {
            XCTFail("latestBlockHeight failed")
            return
        }
    }
    
    func testStoreOneBlockFromEmptyAsync() async throws {
        let initialHeight = try await compactBlockDao.latestHeightAsync()
        guard initialHeight == BlockHeight.empty() else {
            XCTFail("database not empty, latest height: \(initialHeight)")
            return
        }
        
        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create randem block with height: \(expectedHeight)")
            return
        }
        try await compactBlockDao.writeAsync(blocks: [block])
        
        let result = try await compactBlockDao.latestHeightAsync()
        XCTAssertEqual(result, expectedHeight)
    }
    
    func testRewindTo() {
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try TestDbBuilder.seed(db: compactBlockDao, with: startHeight...finalHeight)
        } catch {
            XCTFail("seed faild with error: \(error)")
            return
        }
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        XCTAssertNoThrow(try compactBlockDao.rewind(to: rewindHeight))
        do {
            let latestHeight = try compactBlockDao.latestHeight()
            XCTAssertEqual(latestHeight, rewindHeight - 1)
        } catch {
            XCTFail("Rewind latest block failed with error: \(error)")
        }
    }
    
    func testRewindToAsync() async throws {
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try TestDbBuilder.seed(db: compactBlockDao, with: startHeight...finalHeight)
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        try await compactBlockDao.rewindAsync(to: rewindHeight)
        let latestHeight = try await compactBlockDao.latestHeightAsync()
        XCTAssertEqual(latestHeight, rewindHeight - 1)
    }
}
