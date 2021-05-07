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
        deleteDBs()
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    private func deleteDBs() {
        try? FileManager.default.removeItem(at: cacheDbURL)
        try? FileManager.default.removeItem(at: dataDbURL)
    }
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        operationQueue.cancelAllOperations()
        
        try? FileManager.default.removeItem(at: cacheDbURL)
        try? FileManager.default.removeItem(at: dataDbURL)
    }
    
    func testSingleDownloadAndScanOperation() {
        XCTAssertNoThrow(try rustWelding.initDataDb(dbData: dataDbURL))
        
        let downloadStartedExpect = XCTestExpectation(description: self.description + "download started")
        let downloadExpect = XCTestExpectation(description: self.description + "download")
        let scanStartedExpect = XCTestExpectation(description: self.description + "scan started")
        let scanExpect = XCTestExpectation(description: self.description + "scan")
        let latestScannedBlockExpect = XCTestExpectation(description: self.description + "latestScannedHeight")
        let service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        let blockCount = 100
        let range = ZcashSDK.SAPLING_ACTIVATION_HEIGHT ... ZcashSDK.SAPLING_ACTIVATION_HEIGHT + blockCount
        let downloadOperation = CompactBlockDownloadOperation(downloader: CompactBlockDownloader.sqlDownloader(service: service, at: cacheDbURL)!, range: range)
        let scanOperation = CompactBlockScanningOperation(rustWelding: rustWelding, cacheDb: cacheDbURL, dataDb: dataDbURL)
        
        downloadOperation.startedHandler = {
            downloadStartedExpect.fulfill()
        }
        
        downloadOperation.completionHandler = { (finished, cancelled) in
            downloadExpect.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }
        
        downloadOperation.errorHandler = { (error) in
            XCTFail("Download Operation failed with Error: \(error)")
        }
        
        scanOperation.startedHandler = {
            scanStartedExpect.fulfill()
        }
        
        scanOperation.completionHandler = { (finished, cancelled) in
            scanExpect.fulfill()
            XCTAssertFalse(cancelled)
            XCTAssertTrue(finished)
        }
        
        scanOperation.errorHandler = { (error) in
            XCTFail("Scan Operation failed with Error: \(error)")
        }
        
        scanOperation.addDependency(downloadOperation)
        var latestScannedheight = BlockHeight.empty()
        let latestScannedBlockOperation = BlockOperation {
            let repository = BlockSQLDAO(dbProvider: SimpleConnectionProvider.init(path: self.dataDbURL.absoluteString, readonly: true))
            latestScannedheight = repository.lastScannedBlockHeight()
        }
        
        latestScannedBlockOperation.completionBlock = {
            latestScannedBlockExpect.fulfill()
            XCTAssertEqual(latestScannedheight, range.upperBound)
        }
        
        latestScannedBlockOperation.addDependency(scanOperation)
        
        operationQueue.addOperations([downloadOperation,scanOperation,latestScannedBlockOperation], waitUntilFinished: false)
        
        
        wait(for: [downloadStartedExpect, downloadExpect, scanStartedExpect, scanExpect,latestScannedBlockExpect], timeout: 10, enforceOrder: true)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
