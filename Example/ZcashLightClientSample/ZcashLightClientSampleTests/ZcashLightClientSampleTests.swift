//
//  ZcashLightClientSampleTests.swift
//  ZcashLightClientSampleTests
//
//  Created by Francisco Gindre on 06/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
    
import XCTest
@testable import ZcashLightClientKit
@testable import ZcashLightClientSample

class ZcashLightClientSampleTests: XCTestCase {

    var dbData: URL? = nil
    
    override func setUp() {
        let dataDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        dbData = dataDir.appendingPathComponent("data.db")
    }
    
    override func tearDown() {
        // Delete test database between runs
        do {
            try FileManager.default.removeItem(at: dbData!)
        } catch {
        }
    }
    
    func testInitAndGetAddress() {
        let seed = "seed"
        
        XCTAssertNoThrow(try ZcashRustBackend.initDataDb(dbData: dbData!))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
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

}
