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
    
    let networkType = NetworkType.testnet
    
    override func setUp() {
        dbData = try! __dataDbURL()
        try? dataDbHandle.setUp()
    }
    
    override func tearDown() {
        
        try? FileManager.default.removeItem(at: dbData!)
        dataDbHandle.dispose()
    }
    
    func testInitWithShortSeedAndFail() {
        let seed = "testreferencealice"
        
        XCTAssertNoThrow(try ZcashRustBackend.initDataDb(dbData: dbData!, networkType: networkType))
        
        let _ = ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1, networkType: networkType)
        XCTAssertNotNil(ZcashRustBackend.getLastError())
 
    }
    
    func testDeriveExtendedSpendingKeys() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        
        var spendingKeys: [String]? = nil
        XCTAssertNoThrow(try { spendingKeys = try ZcashRustBackend.deriveExtendedSpendingKeys(seed: seed, accounts: 1, networkType: networkType) }())
        
        XCTAssertNotNil(spendingKeys)
        XCTAssertFalse(spendingKeys?.first?.isEmpty ?? true)
        
    }
    
    func testDeriveExtendedFullViewingKeys() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        
        var fullViewingKeys: [String]? = nil
        XCTAssertNoThrow(try { fullViewingKeys = try ZcashRustBackend.deriveExtendedFullViewingKeys(seed: seed, accounts: 1, networkType: networkType) }())
        
        XCTAssertNotNil(fullViewingKeys)
        XCTAssertFalse(fullViewingKeys?.first?.isEmpty ?? true)
    }
    
    func testDeriveExtendedFullViewingKey() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        var fullViewingKey: String? = nil
        
        
        var spendingKeys: [String]? = nil
        XCTAssertNoThrow(try { spendingKeys = try ZcashRustBackend.deriveExtendedSpendingKeys(seed: seed, accounts: 1, networkType: networkType) }())
        
        XCTAssertNotNil(spendingKeys)
        XCTAssertFalse(spendingKeys?.first?.isEmpty ?? true)
        
        guard let spendingKey = spendingKeys?.first else {
            XCTFail("no spending key generated")
            return
        }
        
        XCTAssertNoThrow(try { fullViewingKey = try ZcashRustBackend.deriveExtendedFullViewingKey(spendingKey, networkType: networkType) }())
        
        XCTAssertNotNil(fullViewingKey)
        XCTAssertFalse(fullViewingKey?.isEmpty ?? true)
    }
    
    func testInitAndScanBlocks() {
        guard  let cacheDb = Bundle(for: Self.self).url(forResource: "cache", withExtension: "db") else {
            XCTFail("pre populated Db not present")
            return
        }
        let seed = "testreferencealicetestreferencealice"
        XCTAssertNoThrow(try ZcashRustBackend.initDataDb(dbData: dbData!, networkType: networkType))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        XCTAssertNotNil(ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1, networkType: networkType))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        let addr = ZcashRustBackend.getAddress(dbData: dbData!, account: 0, networkType: networkType)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        XCTAssertEqual(addr, Optional("ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"))
        
        XCTAssertTrue(ZcashRustBackend.scanBlocks(dbCache: cacheDb, dbData: dbData, networkType: networkType))
        
    }
    
    func testIsValidTransparentAddressFalse() {
        var isValid: Bool? = nil
        
        XCTAssertNoThrow(try { isValid = try ZcashRustBackend.isValidTransparentAddress("ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc", networkType: networkType) }())
        
        if let valid = isValid {
            XCTAssertFalse(valid)
        } else {
            XCTFail()
        }
        
        
    }
    
    func testIsValidTransparentAddressTrue() {
        var isValid: Bool? = nil
        
        XCTAssertNoThrow(try { isValid = try ZcashRustBackend.isValidTransparentAddress("tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7", networkType: networkType) }())
        
        if let valid = isValid {
            XCTAssertTrue(valid)
        } else {
            XCTFail()
        }
    }
    
    func testIsValidShieldedAddressTrue() {
        var isValid: Bool? = nil
        
        XCTAssertNoThrow(try { isValid = try ZcashRustBackend.isValidShieldedAddress("ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc", networkType: networkType) }())
        
        if let valid = isValid {
            XCTAssertTrue(valid)
        } else {
            XCTFail()
        }
    }
    
    func testIsValidShieldedAddressFalse() {
        var isValid: Bool? = nil
        
        XCTAssertNoThrow(try { isValid = try ZcashRustBackend.isValidShieldedAddress("tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7", networkType: networkType) }())
        
        if let valid = isValid {
            XCTAssertFalse(valid)
        } else {
            XCTFail()
        }
    }
    
}
