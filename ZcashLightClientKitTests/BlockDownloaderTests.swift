//
//  BlockDownloaderTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit
class BlockDownloaderTests: XCTestCase {
    
    var downloader: CompactBlockDownloading!
    var service: LightWalletService!
    var storage: CompactBlockRepository!
    var cacheDB = try! __cacheDbURL()
    override func setUp() {
        service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        storage = try! TestDbBuilder.diskCompactBlockStorage(at: cacheDB)
        downloader = CompactBlockDownloader(service: service, storage: storage)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        service = nil
        storage = nil
        downloader = nil
        try? FileManager.default.removeItem(at: cacheDB)
    }
    
    func testSmallDownloadAsync() {
        
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 3
        let lowerRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange,upperRange))
        downloader.downloadBlockRange(range) { (error) in
            expect.fulfill()
            XCTAssertNil(error)
            
            // check what was 'stored'
            self.storage.latestHeight { (result) in
                expect.fulfill()
                
                XCTAssertTrue(self.validate(result: result, against: upperRange))
                
                self.downloader.lastDownloadedBlockHeight { (resultHeight) in
                    expect.fulfill()
                    XCTAssertTrue(self.validate(result: resultHeight, against: upperRange))
                }
            }
        }
        
        wait(for: [expect], timeout: 2)
    }
    
    func testSmallDownload() {
        
        let lowerRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange,upperRange))
        var latest: BlockHeight = 0
        
        do {
            latest = try downloader.lastDownloadedBlockHeight()
        } catch {
            XCTFail(error.localizedDescription)
        }
        
        XCTAssertEqual(latest, BlockHeight.empty())
        XCTAssertNoThrow(try downloader.downloadBlockRange(range))
        
        var currentLatest: BlockHeight = 0
        do {
            currentLatest = try downloader.lastDownloadedBlockHeight()
            
        } catch {
            XCTFail("latest block failed")
            return
        }
        XCTAssertEqual(currentLatest,upperRange )
        
    }
    
    func testFailure() {
        let awfulDownloader = CompactBlockDownloader(service: AwfulLightWalletService(latestBlockHeight: ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 1000), storage: ZcashConsoleFakeStorage())
        
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 1
        let lowerRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange,upperRange))
        
        awfulDownloader.downloadBlockRange(range) { (error) in
            expect.fulfill()
            XCTAssertNotNil(error)
        }
        wait(for: [expect], timeout: 2)
    }
}

/// Helper functions

extension BlockDownloaderTests {
    func validate(result: Result<BlockHeight,Error> ,against height: BlockHeight) -> Bool  {
        
        switch result {
        case .success(let resultHeight):
            return resultHeight == height
        default:
            return false
        }
        
    }
}
