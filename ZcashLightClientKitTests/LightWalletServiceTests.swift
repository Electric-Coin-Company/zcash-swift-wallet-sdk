//
//  LightWalletServiceTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit
import SwiftGRPC
class LightWalletServiceTests: XCTestCase {
    
    var service: LightWalletService!
    var channel: Channel!
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        channel = ChannelProvider().channel()
        service = LightWalletGRPCService(channel: channel)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        channel.shutdown()
    }

    func testFailure() {
        
        let expect = XCTestExpectation(description: self.description)
        let excessivelyHugeRange = Range<BlockHeight>(uncheckedBounds: (lower: 280_000, upper: 600_000))
        service.blockRange(excessivelyHugeRange) { (result) in
            XCTAssertEqual(result, .failure(LightWalletServiceError.failed(statusCode: SwiftGRPC.StatusCode.unknown)))
            expect.fulfill()
            
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testHundredBlocks() {
        let expect = XCTestExpectation(description: self.description)
        
        let lowerRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT + 99
        let blockRange = Range<BlockHeight>(uncheckedBounds: (lower: lowerRange, upper: upperRange))
        
        service.blockRange(blockRange) { (result) in
            expect.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("failed with error \(error)")
                
            case .success(let blocks):
                XCTAssertEqual(blocks.count, 100)
                XCTAssertEqual(blocks[0].height, lowerRange)
            }
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testSyncBlockRange() {
        let lowerRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = SAPLING_ACTIVATION_HEIGHT + 99
        let blockRange = CompactBlockRange(uncheckedBounds: (lower: lowerRange, upper: upperRange))
        
        do {
            let blocks = try service.blockRange(blockRange)
            XCTAssertEqual(blocks.count, blockRange.count + 1)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testLatestBlock(){
        let expect = XCTestExpectation(description: self.description)
        service.latestBlockHeight { (result) in
            expect.fulfill()
            switch result {
            case .failure(let e):
                XCTFail("error: \(e)")
            case .success(let height):
                XCTAssertTrue(height > SAPLING_ACTIVATION_HEIGHT)
            }
        }
        
        wait(for: [expect], timeout: 5)
    }
   
}
