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

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        service = try LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
    }
    
    func testHundredBlocks() {
        let expect = XCTestExpectation(description: self.description)
        let count = 99
        let lowerRange: BlockHeight = network.constants.saplingActivationHeight
        let upperRange: BlockHeight = network.constants.saplingActivationHeight + count
        let blockRange = lowerRange ... upperRange
        
        service.blockRange(blockRange) { result in
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
        let lowerRange: BlockHeight = network.constants.saplingActivationHeight
        let upperRange: BlockHeight = network.constants.saplingActivationHeight + 99
        let blockRange = lowerRange ... upperRange
        
        do {
            let blocks = try service.blockRange(blockRange)
            XCTAssertEqual(blocks.count, blockRange.count)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testLatestBlock() {
        let expect = XCTestExpectation(description: self.description)
        service.latestBlockHeight { result in
            expect.fulfill()
            switch result {
            case .failure(let e):
                XCTFail("error: \(e)")
            case .success(let height):
                XCTAssertTrue(height > self.network.constants.saplingActivationHeight)
            }
        }
        
        wait(for: [expect], timeout: 10)
    }

    func testServerChanges() throws {
        let expectedEndpoint = LightWalletEndpoint(address: "localhost", port: 9067)

        let service = try LightWalletGRPCService(endpoint: LightWalletEndpoint(address: "mainnet.lightwalletd.com", port: 9067))

        XCTAssertEqual(service.currentEndpoint.host, "mainnet.lightwalletd.com")

        try service.switchToEndpoint(expectedEndpoint)

        XCTAssertEqual(service.currentEndpoint.host, expectedEndpoint.host)
    }
}
