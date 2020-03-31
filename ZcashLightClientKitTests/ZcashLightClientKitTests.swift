//
//  ZcashLightClientKitTests.swift
//  ZcashLightClientKitTests
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import GRPC

@testable import ZcashLightClientKit

class ZcashLightClientKitTests: XCTestCase {
    
    var latestBlockHeight: BlockHeight!
    
    var service: LightWalletGRPCService!
    override func setUp() {
        super.setUp()
        service = LightWalletGRPCService(channel: ChannelProvider().channel())
        
        latestBlockHeight = try! service.latestBlock().compactBlockHeight()!
    }
    
    override func tearDown() {
        super.tearDown()
        service.channel.shutdown()
        service = nil
        latestBlockHeight = nil
    }
    
    func testEnvironmentLaunch() {
        
        let address = Constants.address
        
        XCTAssertFalse(address.isEmpty, "Your \'\(Environment.lightwalletdKey)\' key is missing from your launch environment variables")
    }
    
    func testService() {
        
        // and that it has a non-zero size
        XCTAssert(latestBlockHeight > 0)
        
    }
    
    func testBlockRangeServiceTilLastest() {
        let expectedCount: BlockHeight = 99
        var count: BlockHeight = 0
        
        let startHeight = latestBlockHeight - expectedCount
        let endHeight = latestBlockHeight!
        
        guard let call = try? service!.blockRange(startHeight: startHeight, endHeight: endHeight,result: {
            result in
            XCTAssert(result.success)
          
        }) else {
            XCTFail("failed to create getBlockRange( \(startHeight) ..<= \(endHeight)")
            return
        }
        
        var blocks = [CompactBlock]()
        while true {
            guard let block = try? call.receive() else {
               
                break
                
            }
            blocks.append(block)
            count += 1
        }
     
        XCTAssertEqual(expectedCount + 1, count)
        
    }
    
}

class Environment {
    static let lightwalletdKey = "LIGHTWALLETD_ADDRESS"
}
