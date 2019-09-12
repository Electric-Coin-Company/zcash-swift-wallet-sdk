//
//  ZcashLightClientKitTests.swift
//  ZcashLightClientKitTests
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit

class ZcashLightClientKitTests: XCTestCase {

    static var latestBlock: BlockID = try! LightWalletGRPCService.shared.latestBlock()

     func testEnvironmentLaunch() {
         
         let address = Environment.address
         
         XCTAssertFalse(address.isEmpty, "Your \'\(Environment.lightwalletdKey)\' key is missing from your launch environment variables")
     }
     
     func testService() {
    
         // and that it has a non-zero size
         XCTAssert(Self.latestBlock.height > 0)
         
     }
     
     func testBlockRangeService() {

         let expect = XCTestExpectation(description: self.debugDescription)
         let _ = try? LightWalletGRPCService.shared.getAllBlocksSinceSaplingLaunch(){ result in
             print(result)
             expect.fulfill()
             XCTAssert(result.success)
             XCTAssertNotNil(result.resultData)
         }
         wait(for: [expect], timeout: 10)
     }
     
     func testBlockRangeServiceTilLastest() {
         let expectedCount: UInt64 = 99
         var count: UInt64 = 0
         let expect = XCTestExpectation(description: self.debugDescription)
         
         let startHeight = Self.latestBlock.height - expectedCount
         let endHeight = Self.latestBlock.height
         guard let call = try? LightWalletGRPCService.shared.blockRange(startHeight: startHeight, endHeight: endHeight,result: {
             result in
                        XCTAssert(result.success)
                    
         }) else {
             XCTFail("failed to create getBlockRange( \(startHeight) ..<= \(endHeight)")
             return
         }
         wait(for: [expect], timeout: 20)
         
         while let _ = try? call.receive() {
             expect.fulfill()
             count += 1
         }
         
         XCTAssertEqual(expectedCount + 1, count)
         
     }

}
