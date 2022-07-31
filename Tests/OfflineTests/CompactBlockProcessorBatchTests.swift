//
//  CompactBlockProcessorTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 20/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable force_try implicitly_unwrapped_optional
class CompactBlockProcessorBatchTests: XCTestCase {
    let processorConfig = CompactBlockProcessor.Configuration.standard(
        for: ZcashNetworkBuilder.network(for: .testnet),
        walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
    )
    var processor: CompactBlockProcessor!
    var downloadStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var startedValidatingNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let mockLatestHeight = ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight + 2000

    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = SampleLogger(logLevel: .debug)

        let service = MockLightWalletService(
            latestBlockHeight: mockLatestHeight,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
        )
        let branchID = try ZcashRustBackend.consensusBranchIdFor(height: Int32(mockLatestHeight), networkType: network.networkType)
        service.mockLightDInfo = LightdInfo.with({ info in
            info.blockHeight = UInt64(mockLatestHeight)
            info.branch = "asdf"
            info.buildDate = "today"
            info.buildUser = "testUser"
            info.chainName = "test"
            info.consensusBranchID = branchID.toString()
            info.estimatedHeight = UInt64(mockLatestHeight)
            info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        })

        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()

        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        try ZcashRustBackend.initDataDb(dbData: processorConfig.dataDb, networkType: .testnet)
    }

    override func tearDown() {
        super.tearDown()
        try! FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
      
        NotificationCenter.default.removeObserver(self)
    }


    func testNextBatchBlockRange() {
        // test first range
        var latestDownloadedHeight = processorConfig.walletBirthday // this can be either -1 or Wallet Birthday.
        var latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        var expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight, upper:latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestDownloadedHeight,
                walletBirthday: processorConfig.walletBirthday,
                network: network
            )
        )

        // Test mid-range
        latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight + ZcashSDK.DefaultDownloadBatch)
        latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight + 1, upper: latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestDownloadedHeight,
                walletBirthday: processorConfig.walletBirthday,
                network: network
            )
        )

        // Test last batch range

        latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight + 950)
        latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight + 1, upper: latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestDownloadedHeight,
                walletBirthday: processorConfig.walletBirthday,
                network: network
            )
        )
    }

    func testDetermineLowerBoundPastBirthday() {
        let errorHeight = 781_906

        let walletBirthday = 781_900

        let result = processor.determineLowerBound(errorHeight: errorHeight, consecutiveErrors: 1, walletBirthday: walletBirthday)
        let expected = 781_886

        XCTAssertEqual(result, expected)
    }

    func testDetermineLowerBound() {
        let errorHeight = 781_906

        let walletBirthday = 780_900

        let result = processor.determineLowerBound(errorHeight: errorHeight, consecutiveErrors: 0, walletBirthday: walletBirthday)
        let expected = 781_896

        XCTAssertEqual(result, expected)
    }

    func testWhenDownloadCacheIsEmptyAndScannedHeightIsEmptyNextBatchStartsFromBirthday() throws {
        // test first range
        let latestDownloadedHeight = BlockHeight.empty()
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight.empty()

        let expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: birthday, upper:latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testWhenDownloadCacheIsEmptyAndScannedHeightIsNotEmptyNextBatchStartsFromScannedHeightPlusOne() throws {
        let latestDownloadedHeight = BlockHeight.empty()
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 100)

        let expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestScannedHeight + 1, upper:latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testWhenDownloadIsAheadFromPresentScannedHeight() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 100)
        let latestDownloadedHeight = BlockHeight(latestScannedHeight + 100)

        let expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight + 1, upper:latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    /// this is an strange scenario. I would mean that there's a chunk of outdated cache and
    /// latest scanned block is reported head of it.
    func testWhenDownloadCacheIsBehindScannedHeightIsNotEmpty() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 500)
        let latestDownloadedHeight = BlockHeight(birthday + 100)

        let expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestScannedHeight + 1, upper:latestBlockchainHeight))

        XCTAssertEqual(
            expectedBatchRange,
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testReturnsNilWhenLatestBlockHeightIsBehindDownloadHeight() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 400)
        let latestScannedHeight = BlockHeight(birthday + 500)
        let latestDownloadedHeight = BlockHeight(birthday + 100)

        XCTAssertNil(
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }


    func testReturnsNilWhenBirthdayIsInvalid() throws {
        let birthday = BlockHeight(-1)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 500)
        let latestDownloadedHeight = BlockHeight(birthday + 100)

        XCTAssertNil(
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testReturnsNilWhenLatestBlockchainHeightIsInvalid() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(-1)
        let latestScannedHeight = BlockHeight(birthday + 500)
        let latestDownloadedHeight = BlockHeight(birthday + 100)

        XCTAssertNil(
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testReturnsNilWhenLatestScannedHeightIsInvalid() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 100)
        let latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight - 1000)

        XCTAssertNil(
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }

    func testReturnsNilWhenLatestDownloadedHeightIsInvalid() throws {
        let birthday = BlockHeight(663150)
        let latestBlockchainHeight = BlockHeight(birthday + 1000)
        let latestScannedHeight = BlockHeight(birthday + 100)
        let latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight - 1000)

        XCTAssertNil(
            CompactBlockProcessor.nextDownloadBatchBlockRange(
                latestHeight: latestBlockchainHeight,
                latestDownloadedHeight: latestDownloadedHeight,
                latestScannedHeight: latestScannedHeight,
                walletBirthday: birthday,
                network: network
            )
        )
    }
}


