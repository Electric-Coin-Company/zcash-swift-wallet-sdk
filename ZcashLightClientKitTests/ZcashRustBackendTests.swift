//
//  ZcashRustBackendTests.swift
//  ZcashLightClientKitTests
//
//  Created by Jack Grigg on 28/06/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit

class ZcashRustBackendTests: XCTestCase {
    var dbData: URL!
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)
    var cacheDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedCacheDbURL()!)
    let spendingKey = "secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4kwlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcq9rc0qn"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    let zpend: Int = 500_000
    override func setUp() {
        dbData = try! __dataDbURL()
        try? dataDbHandle.setUp()
    }
    
    override func tearDown() {
        
        try? FileManager.default.removeItem(at: dbData!)
        dataDbHandle.dispose()
    }
    
    func testInitAndGetAddress() {
        let seed = "seed"
        
        XCTAssertNoThrow(try ZcashRustBackend.initDataDb(dbData: dbData!))
        
        let _ = ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        let addr = ZcashRustBackend.getAddress(dbData: dbData!, account: 0)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        XCTAssertEqual(addr, Optional("ztestsapling1meqz0cd598fw0jlq2htkuarg8gqv36fam83yxmu5mu3wgkx4khlttqhqaxvwf57urm3rqsq9t07"))
        
        // Test invalid account
        let addr2 = ZcashRustBackend.getAddress(dbData: dbData!, account: 1)
        XCTAssert(ZcashRustBackend.getLastError() != nil)
        XCTAssertEqual(addr2, nil)
    }
    
    func testInitAndScanBlocks() {
        guard  let cacheDb = Bundle(for: Self.self).url(forResource: "cache", withExtension: "db") else {
            XCTFail("pre populated Db not present")
            return
        }
        let seed = "testreferencealice"
        XCTAssertNoThrow(try ZcashRustBackend.initDataDb(dbData: dbData!))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        XCTAssertNotNil(ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        let addr = ZcashRustBackend.getAddress(dbData: dbData!, account: 0)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        XCTAssertEqual(addr, Optional("ztestsapling12pxv67r0kdw58q8tcn8kxhfy9n4vgaa7q8vp0dg24aueuz2mpgv2x7mw95yetcc37efc6q3hewn"))
        
        XCTAssertTrue(ZcashRustBackend.scanBlocks(dbCache: cacheDb, dbData: dbData))
        
    }
    
    func testSendToAddress() {
        
        let tx = try! ZcashRustBackend.createToAddress(dbData: dataDbHandle.readWriteDb, account: 0, extsk: spendingKey, to: recipientAddress, value: Int64(zpend), memo: nil, spendParams: URL(string: __spendParamsURL().path)!, outputParams: URL(string: __outputParamsURL().path)!)
        XCTAssert(tx > 0)
        XCTAssertNil(ZcashRustBackend.lastError())
    }
}
