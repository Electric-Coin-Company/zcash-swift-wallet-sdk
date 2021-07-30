//
//  LightWalletServiceTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit
import GRPC
class LightWalletServiceTests: XCTestCase {
    
    var service: LightWalletService!
    var channel: Channel!
    let network: ZcashNetwork = ZcashNetworkBuilder.network(for: .testnet)
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        channel = ChannelProvider().channel()
        service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// FIXME: check whether this test is stil valid on in memory lwd implementatiojn
//    func testFailure() {
//
//        let expect = XCTestExpectation(description: self.description)
//        let excessivelyHugeRange = Range<BlockHeight>(uncheckedBounds: (lower: 280_000, upper: 600_000))
//        service.blockRange(excessivelyHugeRange) { (result) in
//            XCTAssertEqual(result, .failure(LightWalletServiceError.failed(statusCode: SwiftGRPC.StatusCode.cancelled)))
//            expect.fulfill()
//
//        }
//        wait(for: [expect], timeout: 20)
//    }
    
    func testHundredBlocks() {
        let expect = XCTestExpectation(description: self.description)
        let count = 99
        let lowerRange: BlockHeight = network.constants.SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = network.constants.SAPLING_ACTIVATION_HEIGHT + count
        let blockRange = lowerRange ... upperRange
        
        service.blockRange(blockRange) { (result) in
            expect.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("failed with error \(error)")
                
            case .success(let blocks):
                XCTAssertEqual(blocks.count, blockRange.count)
                XCTAssertEqual(blocks[0].height, lowerRange)
                XCTAssertEqual(blocks.last!.height, upperRange)
            }
        }
        
        wait(for: [expect], timeout: 10)
    }
    
    func testSyncBlockRange() {
        let lowerRange: BlockHeight = network.constants.SAPLING_ACTIVATION_HEIGHT
        let upperRange: BlockHeight = network.constants.SAPLING_ACTIVATION_HEIGHT + 99
        let blockRange = lowerRange ... upperRange
        
        do {
            let blocks = try service.blockRange(blockRange)
            XCTAssertEqual(blocks.count, blockRange.count)
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
                XCTAssertTrue(height > self.network.constants.SAPLING_ACTIVATION_HEIGHT)
            }
        }
        
        wait(for: [expect], timeout: 10)
    }
   
}
