//
//  DownloadOperationTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import SQLite
@testable import ZcashLightClientKit
class DownloadOperationTests: XCTestCase {
    
    var operationQueue = OperationQueue()

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        operationQueue.cancelAllOperations()
    }

    func testSingleOperation() {
        let expect = XCTestExpectation(description: self.description)
        
        let service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        let storage = try! TestDbBuilder.inMemoryCompactBlockStorage()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        let blockCount = 100
        let range = ZcashSDK.SAPLING_ACTIVATION_HEIGHT ... ZcashSDK.SAPLING_ACTIVATION_HEIGHT + blockCount
        let downloadOperation = CompactBlockDownloadOperation(downloader: downloader, range: range)
        
        downloadOperation.completionHandler = { (finished, cancelled) in
            expect.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }
        
        downloadOperation.errorHandler = { (error) in
            XCTFail("Donwload Operation failed with error: \(error)")
        }
        
        operationQueue.addOperation(downloadOperation)
        
        wait(for: [expect], timeout: 10)
        
        XCTAssertEqual(try! storage.latestHeight(),range.upperBound)
    }

}
