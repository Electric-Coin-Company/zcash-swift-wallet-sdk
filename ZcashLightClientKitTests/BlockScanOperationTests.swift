//
//  BlockScanOperationTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/17/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import SQLite
@testable import ZcashLightClientKit
class BlockScanOperationTests: XCTestCase {
    
    var operationQueue = OperationQueue()
    var cacheDbURL: URL!
    var dataDbURL: URL!
    let rustWelding = ZcashRustBackend.self
    
    var blockRepository: BlockRepository!
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.cacheDbURL = try! __cacheDbURL()
        self.dataDbURL = try! __dataDbURL()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        operationQueue.cancelAllOperations()
        
//        try! FileManager.default.removeItem(at: cacheDbURL)
        try? FileManager.default.removeItem(at: dataDbURL)
    }

    func testSingleDownloadAndScanOperation() {
        guard rustWelding.initDataDb(dbData: dataDbURL) else {
            XCTFail("could not initialize data DB")
            return
        }
        blockRepository = try! BlockSQLDAO(dataDb: dataDbURL)
        
        let downloadExpect = XCTestExpectation(description: self.description + "download")
        let scanExpect = XCTestExpectation(description: self.description + "scan")
        let service = LightWalletGRPCService(channel: ChannelProvider().channel())
        let storage = try! TestDbBuilder.diskCompactBlockStorage(at: cacheDbURL)
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        let blockCount = 100
        let range = SAPLING_ACTIVATION_HEIGHT ..< SAPLING_ACTIVATION_HEIGHT + blockCount
        let downloadOperation = CompactBlockDownloadOperation(downloader: downloader, range: range)
        let scanOperation = CompactBlockScanningOperation(rustWelding: rustWelding, cacheDb: cacheDbURL, dataDb: dataDbURL)
        
        downloadOperation.completionHandler = { (finished, cancelled, error) in
            downloadExpect.fulfill()
            XCTAssertNil(error)
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }
        
        scanOperation.completionHandler = { (finished, cancelled, error) in
            scanExpect.fulfill()
            XCTAssertNil(error)
            XCTAssertFalse(cancelled)
            XCTAssertTrue(finished)
        }
        scanOperation.addDependency(downloadOperation)
        operationQueue.addOperation(downloadOperation)
        operationQueue.addOperation(scanOperation)
        
        wait(for: [downloadExpect, scanExpect], timeout: 5, enforceOrder: true)
        
        XCTAssertEqual(try! storage.latestHeight(),range.endIndex)
        XCTAssertEqual(blockRepository.lastScannedBlockHeight(), range.endIndex)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
