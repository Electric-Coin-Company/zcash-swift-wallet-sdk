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
    var storage: CompactBlockAsyncStoring!
    override func setUp() {
        service = LightWalletGRPCService(channel: ChannelProvider().channel())
        storage =  ZcashConsoleFakeStorage()
        downloader = CompactBlockDownloader(service: service, storage: storage)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        service = nil
        storage = nil
        downloader = nil
    }

    
    func testSmallDownload() {
        
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 3
        let lowerRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange,upperRange))
        downloader.downloadBlockRange(range) { (error) in
            expect.fulfill()
            XCTAssertNil(error)
            
            // check what was 'stored'
            self.storage.latestHeight { (result) in
                expect.fulfill()
                
                XCTAssertTrue(self.validate(result: result, against: upperRange))
                
                self.downloader.latestBlockHeight { (resultHeight) in
                    expect.fulfill()
                    XCTAssertTrue(self.validate(result: resultHeight, against: upperRange))
                }
            }
        }
        
        wait(for: [expect], timeout: 2)
    }
    
    
    func testFailure() {
        let awfulDownloader = CompactBlockDownloader(service: AwfulLightWalletService(), storage: ZcashConsoleFakeStorage())
        
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 1
        let lowerRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT + 99
        
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
