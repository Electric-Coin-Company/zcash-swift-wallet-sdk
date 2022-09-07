//
//  ZcashRustBackendTests.swift
//  ZcashLightClientKitTests
//
//  Created by Jack Grigg on 28/06/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional force_try
class ZcashRustBackendTests: XCTestCase {
    var dbData: URL!
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)
    var cacheDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedCacheDbURL()!)
    let spendingKey =
        // swiftlint:disable:next line_length
        "secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4kwlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcq9rc0qn"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    let zpend: Int = 500_000
    
    let networkType = NetworkType.testnet
    
    override func setUp() {
        super.setUp()
        dbData = try! __dataDbURL()
        try? dataDbHandle.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: dbData!)
        dataDbHandle.dispose()
    }
    
    func testInitWithShortSeedAndFail() {
        let seed = "testreferencealice"

        var dbInit: DbInitResult!
        XCTAssertNoThrow(try { dbInit = try ZcashRustBackend.initDataDb(dbData: self.dbData!, seed: nil, networkType: self.networkType) }())

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }

        _ = ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1, networkType: networkType)
        XCTAssertNotNil(ZcashRustBackend.getLastError())
    }
    
    func testDeriveExtendedSpendingKeys() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        
        var spendingKeys: [SaplingExtendedSpendingKey]?
        XCTAssertNoThrow(try { spendingKeys = try ZcashRustBackend.deriveSaplingExtendedSpendingKeys(seed: seed, accounts: 1, networkType: networkType) }())
        
        XCTAssertNotNil(spendingKeys)
        XCTAssertEqual(spendingKeys?.count, 1)
    }
    
    func testDeriveExtendedFullViewingKeys() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        
        var fullViewingKeys: [SaplingExtendedFullViewingKey]?
        XCTAssertNoThrow(
            try {
                fullViewingKeys = try ZcashRustBackend.deriveSaplingExtendedFullViewingKeys(
                    seed: seed,
                    accounts: 2,
                    networkType: networkType
                )
            }()
        )
        
        XCTAssertNotNil(fullViewingKeys)
        XCTAssertEqual(fullViewingKeys?.count, 2)
    }
    
    func testDeriveExtendedFullViewingKey() {
        let seed = Array("testreferencealicetestreferencealice".utf8)
        var fullViewingKey: SaplingExtendedFullViewingKey?
        
        var spendingKeys: [SaplingExtendedSpendingKey]?
        XCTAssertNoThrow(try { spendingKeys = try ZcashRustBackend.deriveSaplingExtendedSpendingKeys(seed: seed, accounts: 1, networkType: networkType) }())
        
        XCTAssertNotNil(spendingKeys)
        
        guard let spendingKey = spendingKeys?.first else {
            XCTFail("no spending key generated")
            return
        }
        
        XCTAssertNoThrow(try { fullViewingKey = try ZcashRustBackend.deriveSaplingExtendedFullViewingKey(spendingKey, networkType: networkType) }())
        
        XCTAssertNotNil(fullViewingKey)
    }
    
    func testInitAndScanBlocks() {
        guard let cacheDb = TestDbBuilder.prePopulatedCacheDbURL() else {
            XCTFail("pre populated Db not present")
            return
        }
        let seed = "testreferencealicetestreferencealice"

        var dbInit: DbInitResult!
        XCTAssertNoThrow(try { dbInit = try ZcashRustBackend.initDataDb(dbData: self.dbData!, seed: nil, networkType: self.networkType) }())

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }
        
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        XCTAssertNotNil(ZcashRustBackend.initAccountsTable(dbData: dbData!, seed: Array(seed.utf8), accounts: 1, networkType: networkType))
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        let addr = ZcashRustBackend.getAddress(dbData: dbData!, account: 0, networkType: networkType)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        XCTAssertEqual(addr, Optional("ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"))
        
        XCTAssertTrue(ZcashRustBackend.scanBlocks(dbCache: cacheDb, dbData: dbData, networkType: networkType))
    }
    
    func testIsValidTransparentAddressFalse() {
        var isValid: Bool?
        
        XCTAssertNoThrow(
            try {
                isValid = try ZcashRustBackend.isValidTransparentAddress(
                    "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc",
                    networkType: networkType
                )
            }()
        )
        
        if let valid = isValid {
            XCTAssertFalse(valid)
        } else {
            XCTFail("Failed as invalid")
        }
    }
    
    func testIsValidTransparentAddressTrue() {
        var isValid: Bool?
        
        XCTAssertNoThrow(
            try {
                isValid = try ZcashRustBackend.isValidTransparentAddress(
                    "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7",
                    networkType: networkType
                )
            }()
        )
        
        if let valid = isValid {
            XCTAssertTrue(valid)
        } else {
            XCTFail("Failed as invalid")
        }
    }
    
    func testIsValidSaplingAddressTrue() {
        var isValid: Bool?
        
        XCTAssertNoThrow(
            try {
                isValid = try ZcashRustBackend.isValidSaplingAddress(
                    "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc",
                    networkType: networkType
                )
            }()
        )
        
        if let valid = isValid {
            XCTAssertTrue(valid)
        } else {
            XCTFail("Failed as invalid")
        }
    }
    
    func testIsValidSaplingAddressFalse() {
        var isValid: Bool?
        
        XCTAssertNoThrow(
            try {
                isValid = try ZcashRustBackend.isValidSaplingAddress(
                    "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7",
                    networkType: networkType
                )
            }()
        )
        
        if let valid = isValid {
            XCTAssertFalse(valid)
        } else {
            XCTFail("Failed as invalid")
        }
    }
}
