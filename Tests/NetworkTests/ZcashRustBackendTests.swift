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
    
    func testInitWithShortSeedAndFail() throws {
        let seed = "testreferencealice"

        var dbInit: DbInitResult!
        XCTAssertNoThrow(try { dbInit = try ZcashRustBackend.initDataDb(dbData: self.dbData!, seed: nil, networkType: self.networkType) }())

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }

       XCTAssertThrowsError(try ZcashRustBackend.createAccount(dbData: dbData!, seed: Array(seed.utf8), networkType: networkType))
    }

    func testInitAndScanBlocks() throws {
        guard let cacheDb = TestDbBuilder.prePopulatedCacheDbURL() else {
            XCTFail("pre populated Db not present")
            return
        }
        let seed = "testreferencealicetestreferencealice"

        var dbInit: DbInitResult!
        XCTAssertNoThrow(try { dbInit = try ZcashRustBackend.initDataDb(dbData: self.dbData!, seed: Array(seed.utf8), networkType: self.networkType) }())

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }


        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        let ufvks = [
            try DerivationTool(networkType: networkType).deriveUnifiedSpendingKey(seed: Array(seed.utf8), accountIndex: 0)
                .deriveFullViewingKey()

        ]
        guard try ZcashRustBackend.initAccountsTable(dbData: dbData!, ufvks: ufvks, networkType: networkType) else {
            XCTFail("failed with error: \(String(describing: ZcashRustBackend.lastError()))")
            return
        }
        XCTAssertNotNil(
            try ZcashRustBackend.createAccount(
                dbData: dbData!,
                seed: Array(seed.utf8),
                networkType: networkType
            )
        )
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        
        let addr = try ZcashRustBackend.getCurrentAddress(dbData: dbData!, account: 0, networkType: networkType)
        XCTAssertEqual(ZcashRustBackend.getLastError(), nil)
        XCTAssertEqual(addr.saplingReceiver()?.stringEncoded, Optional("ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"))
        
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

    func testListTransparentReceivers() throws {
        let testVector = [TestVector](TestVector.testVectors![0 ... 2])
        let network = NetworkType.mainnet
        let tempDBs = TemporaryDbBuilder.build()
        let seed = testVector[0].root_seed!
        let ufvk = try DerivationTool(networkType: network).deriveUnifiedSpendingKey(seed: seed, accountIndex: Int(testVector[0].account)).deriveFullViewingKey()

        XCTAssertEqual(
            try ZcashRustBackend.initDataDb(
                dbData: tempDBs.dataDB,
                seed: seed,
                networkType: network
            ),
            .success
        )

//        XCTAssertTrue(
//            try ZcashRustBackend.initAccountsTable(
//                dbData: tempDBs.dataDB,
//                ufvks: [ufvk],
//                networkType: network
//            )
//        )
        XCTAssertNoThrow(
            try ZcashRustBackend.createAccount(
                dbData: tempDBs.dataDB,
                seed: seed,
                networkType: .mainnet
            )
        )

        let expectedReceivers = testVector.map {
            UnifiedAddress(validatedEncoding: $0.unified_addr!)
        }
        .compactMap({ $0.transparentReceiver() })


        guard expectedReceivers.count >= 2 else {
            XCTFail("not enough transparent receivers")
            return
        }

        for _ in [0 ... 2] {
            XCTAssertNoThrow(
                try ZcashRustBackend.getCurrentAddress(
                    dbData: tempDBs.dataDB,
                    account: 0,
                    networkType: network
                )
            )

            XCTAssertNoThrow(
                try ZcashRustBackend.getNextAvailableAddress(
                    dbData: tempDBs.dataDB,
                    account: 0,
                    networkType: network
                )
            )
        }

        XCTAssertEqual(
            expectedReceivers,
            try ZcashRustBackend.listTransparentReceivers(
                dbData: tempDBs.dataDB,
                account: 0,
                networkType: network
            )
        )
    }
}
