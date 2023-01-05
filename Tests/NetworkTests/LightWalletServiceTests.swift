//
//  LightWalletServiceTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit
import GRPC

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping
class LightWalletServiceTests: XCTestCase {
    let network: ZcashNetwork = ZcashNetworkBuilder.network(for: .testnet)

    var service: LightWalletService!
    var channel: Channel!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        channel = ChannelProvider().channel()
        service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
    }

    /// FIXME: check whether this test is still valid on in memory lwd implementation
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
    
    func testHundredBlocks() async throws {
        let count = 99
        let lowerRange: BlockHeight = network.constants.saplingActivationHeight
        let upperRange: BlockHeight = network.constants.saplingActivationHeight + count
        let blockRange = lowerRange ... upperRange
        
        var blocks: [ZcashCompactBlock] = []
        for try await block in service.blockRange(blockRange) {
            blocks.append(block)
        }
        XCTAssertEqual(blocks.count, blockRange.count)
        XCTAssertEqual(blocks[0].height, lowerRange)
        XCTAssertEqual(blocks.last!.height, upperRange)
    }
    
    func testSyncBlockRange() async throws {
        let lowerRange: BlockHeight = network.constants.saplingActivationHeight
        let upperRange: BlockHeight = network.constants.saplingActivationHeight + 99
        let blockRange = lowerRange ... upperRange

        var blocks: [ZcashCompactBlock] = []
        for try await block in service.blockRange(blockRange) {
            blocks.append(block)
        }
        XCTAssertEqual(blocks.count, blockRange.count)
    }
    
    func testLatestBlock() async throws {
        let height = try await service.latestBlockHeightAsync()
        XCTAssertTrue(height > self.network.constants.saplingActivationHeight)
    }
}
