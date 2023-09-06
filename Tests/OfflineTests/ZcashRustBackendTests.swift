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
    var rustBackend: ZcashRustBackendWelding!
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

        rustBackend = ZcashRustBackend.makeForTests(dbData: dbData, fsBlockDbRoot: Environment.uniqueTestTempDirectory, networkType: .testnet)
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: dbData!)
        dataDbHandle.dispose()
        rustBackend = nil
    }
    
    func testInitWithShortSeedAndFail() async throws {
        let seed = "testreferencealice"
        var treeState = TreeState()
        treeState.height = 663193 // TODO: rest

        let dbInit = try await rustBackend.initDataDb(seed: nil)

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }

        do {
            _ = try await rustBackend.createAccount(seed: Array(seed.utf8), treeState: treeState.serializedData(partial: false).bytes, recoverUntil: nil)
            XCTFail("createAccount should fail here.")
        } catch { }
    }

    func testIsValidTransparentAddressFalse() {
        XCTAssertFalse(
            ZcashKeyDerivationBackend(networkType: networkType).isValidTransparentAddress(
                "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"
            )
        )
    }
    
    func testIsValidTransparentAddressTrue() {
        XCTAssertTrue(
            ZcashKeyDerivationBackend(networkType: networkType).isValidTransparentAddress(
                "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7"
            )
        )
    }
    
    func testIsValidSaplingAddressTrue() {
        XCTAssertTrue(
            ZcashKeyDerivationBackend(networkType: networkType).isValidSaplingAddress(
                "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"
            )
        )
    }
    
    func testIsValidSaplingAddressFalse() {
        XCTAssertFalse(
            ZcashKeyDerivationBackend(networkType: networkType).isValidSaplingAddress(
                "tmSwpioc7reeoNrYB9SKpWkurJz3yEj3ee7"
            )
        )
    }

    func testListTransparentReceivers() async throws {
        let testVector = [TestVector](TestVector.testVectors![0 ... 2])
        let tempDBs = TemporaryDbBuilder.build()
        let seed = testVector[0].root_seed!
        rustBackend = ZcashRustBackend.makeForTests(dbData: tempDBs.dataDB, fsBlockDbRoot: Environment.uniqueTestTempDirectory, networkType: .mainnet)

        try? FileManager.default.removeItem(at: tempDBs.dataDB)

        let initResult = try await rustBackend.initDataDb(seed: seed)
        XCTAssertEqual(initResult, .success)

        let treeState = Checkpoint.birthday(with: 1234567, network: ZcashMainnet()).treeState()

        let usk = try await rustBackend.createAccount(seed: seed, treeState: treeState.serializedData(partial: false).bytes, recoverUntil: nil)
        XCTAssertEqual(usk.account, 0)

        let expectedReceivers = try testVector.map {
            UnifiedAddress(validatedEncoding: $0.unified_addr!, networkType: .mainnet)
        }
        .map { try $0.transparentReceiver() }

        let expectedUAs = testVector.map {
            UnifiedAddress(validatedEncoding: $0.unified_addr!, networkType: .mainnet)
        }

        guard expectedReceivers.count >= 2 else {
            XCTFail("not enough transparent receivers")
            return
        }
        var uAddresses: [UnifiedAddress] = []
        for i in 0...2 {
            uAddresses.append(
                try await rustBackend.getCurrentAddress(account: 0)
            )

            if i < 2 {
                _ = try await rustBackend.getNextAvailableAddress(account: 0)
            }
        }

        XCTAssertEqual(
            uAddresses,
            expectedUAs
        )

        let actualReceivers = try await rustBackend.listTransparentReceivers(account: 0)

        XCTAssertEqual(
            expectedReceivers.sorted(),
            actualReceivers.sorted()
        )
    }

    func testGetMetadataFromAddress() throws {
        let recipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"

        let metadata = ZcashKeyDerivationBackend.getAddressMetadata(recipientAddress)

        XCTAssertEqual(metadata?.networkType, .mainnet)
        XCTAssertEqual(metadata?.addressType, .sapling)
    }
}
