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

class ZcashRustBackendTests: XCTestCase {
    var dbData: URL!
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)

    let spendingKey = """
    secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4k\
    wlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658\
    kd4xcq9rc0qn
    """
    
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
    
    func testInitWithShortSeedAndFail() async throws {
        let seed = "testreferencealice"

        let dbInit = try await ZcashRustBackend.initDataDb(dbData: self.dbData!, seed: nil, networkType: self.networkType)

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }

        do {
            _ = try await ZcashRustBackend.createAccount(dbData: dbData!, seed: Array(seed.utf8), networkType: networkType)
            XCTFail("createAccount should fail here.")
        } catch { }
    }

    func testIsValidTransparentAddressFalse() {
        XCTAssertFalse(
            ZcashRustBackend.isValidTransparentAddress(
                "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc",
                networkType: networkType
            )
        )
    }
    
    func testIsValidTransparentAddressTrue() {
        XCTAssertTrue(
            ZcashRustBackend.isValidTransparentAddress(
                "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7",
                networkType: networkType
            )
        )
    }
    
    func testIsValidSaplingAddressTrue() {
        XCTAssertTrue(
            ZcashRustBackend.isValidSaplingAddress(
                "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc",
                networkType: networkType
            )
        )
    }
    
    func testIsValidSaplingAddressFalse() {
        XCTAssertFalse(
            ZcashRustBackend.isValidSaplingAddress(
                "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7",
                networkType: networkType
            )
        )
    }

    func testListTransparentReceivers() async throws {
        let testVector = [TestVector](TestVector.testVectors![0 ... 2])
        let network = NetworkType.mainnet
        let tempDBs = TemporaryDbBuilder.build()
        let seed = testVector[0].root_seed!

        try? FileManager.default.removeItem(at: tempDBs.dataDB)

        let initResult = try await ZcashRustBackend.initDataDb(
            dbData: tempDBs.dataDB,
            seed: seed,
            networkType: network
        )
        XCTAssertEqual(initResult, .success)

        let usk = try await ZcashRustBackend.createAccount(
            dbData: tempDBs.dataDB,
            seed: seed,
            networkType: network
        )
        XCTAssertEqual(usk.account, 0)

        let expectedReceivers = try testVector.map {
            UnifiedAddress(validatedEncoding: $0.unified_addr!)
        }
        .map { try $0.transparentReceiver() }

        let expectedUAs = testVector.map {
            UnifiedAddress(validatedEncoding: $0.unified_addr!)
        }

        guard expectedReceivers.count >= 2 else {
            XCTFail("not enough transparent receivers")
            return
        }
        var uAddresses: [UnifiedAddress] = []
        for i in 0...2 {
            uAddresses.append(
                try await ZcashRustBackend.getCurrentAddress(
                    dbData: tempDBs.dataDB,
                    account: 0,
                    networkType: network
                )
            )

            if i < 2 {
                _ = try await ZcashRustBackend.getNextAvailableAddress(
                    dbData: tempDBs.dataDB,
                    account: 0,
                    networkType: network
                )
            }
        }

        XCTAssertEqual(
            uAddresses,
            expectedUAs
        )

        let actualReceivers = try await ZcashRustBackend.listTransparentReceivers(
            dbData: tempDBs.dataDB,
            account: 0,
            networkType: network
        )

        XCTAssertEqual(
            expectedReceivers.sorted(),
            actualReceivers.sorted()
        )
    }

    func testGetMetadataFromAddress() throws {
        let recipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"

        let metadata = ZcashRustBackend.getAddressMetadata(recipientAddress)

        XCTAssertEqual(metadata?.networkType, .mainnet)
        XCTAssertEqual(metadata?.addressType, .sapling)
    }
}
