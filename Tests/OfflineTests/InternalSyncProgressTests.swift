//
//  InternalSyncProgressTests.swift
//  
//
//  Created by Michal Fousek on 30.11.2022.
//

@testable import TestUtils
import XCTest
@testable import ZcashLightClientKit

class InternalSyncProgressTests: ZcashTestCase {
    var storage: InternalSyncProgressDiskStorage!
    var internalSyncProgress: InternalSyncProgress!

    override func setUp() async throws {
        try await super.setUp()
        for key in InternalSyncProgress.Key.allCases {
            UserDefaults.standard.removeObject(forKey: key.with(.default))
        }

        storage = InternalSyncProgressDiskStorage(storageURL: testGeneralStorageDirectory, logger: logger)
        internalSyncProgress = InternalSyncProgress(alias: .default, storage: storage, logger: logger)
        try await internalSyncProgress.initialize()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        storage = nil
        internalSyncProgress = nil
    }

    func test__trackedValuesAreHigherThanLatestHeight__nextStateIsWait() async throws {
        let latestHeight = 623000
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000, alias: .default)
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = try await internalSyncProgress.computeNextState(
            latestBlockHeight: latestHeight,
            latestScannedHeight: 630000,
            walletBirthday: 600000
        )

        switch nextState {
        case let .wait(latestHeight, latestDownloadHeight):
            XCTAssertEqual(latestHeight, 623000)
            XCTAssertEqual(latestDownloadHeight, 630000)

        default:
            XCTFail("State should be wait. Unexpected state: \(nextState)")
        }
    }

    func test__trackedValuesAreLowerThanLatestHeight__nextStateIsProcessNewBlocks() async throws {
        let latestHeight = 640000
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000, alias: .default)
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = try await internalSyncProgress.computeNextState(
            latestBlockHeight: latestHeight,
            latestScannedHeight: 620000,
            walletBirthday: 600000
        )

        switch nextState {
        case let .processNewBlocks(ranges):
            XCTAssertEqual(ranges.downloadRange, 630001...640000)
            XCTAssertEqual(ranges.scanRange, 620001...640000)
            XCTAssertEqual(ranges.enhanceRange, 630001...640000)
            XCTAssertEqual(ranges.fetchUTXORange, 630001...640000)

        default:
            XCTFail("State should be processNewBlocks. Unexpected state: \(nextState)")
        }
    }

    func test__trackedValuesAreSameAsLatestHeight__nextStateIsFinishProcessing() async throws {
        let latestHeight = 630000
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000, alias: .default)
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = try await internalSyncProgress.computeNextState(
            latestBlockHeight: latestHeight,
            latestScannedHeight: 630000,
            walletBirthday: 600000
        )

        switch nextState {
        case let .finishProcessing(height):
            XCTAssertEqual(height, latestHeight)

        default:
            XCTFail("State should be finishProcessing. Unexpected state: \(nextState)")
        }
    }

    func test__rewindToHeightThatIsHigherThanTrackedHeight__rewindsToTrackedHeight() async throws {
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        try await internalSyncProgress.rewind(to: 640000)

        let latestEnhancedHeight = try await storage.integer(for: "latestEnhancedHeight")
        let latestUTXOFetchedHeight = try await storage.integer(for: "latestUTXOFetchedHeight")
        XCTAssertEqual(latestEnhancedHeight, 630000)
        XCTAssertEqual(latestUTXOFetchedHeight, 630000)
    }

    func test__rewindToHeightThatIsLowerThanTrackedHeight__rewindsToRewindHeight() async throws {
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        try await internalSyncProgress.rewind(to: 620000)

        let latestEnhancedHeight = try await storage.integer(for: "latestEnhancedHeight")
        let latestUTXOFetchedHeight = try await storage.integer(for: "latestUTXOFetchedHeight")
        XCTAssertEqual(latestEnhancedHeight, 620000)
        XCTAssertEqual(latestUTXOFetchedHeight, 620000)
    }

    func test__get__returnsStoredValue() async throws {
        try await storage.set(621000, for: "latestEnhancedHeight")
        let latestEnhancedHeight = try await internalSyncProgress.latestEnhancedHeight
        XCTAssertEqual(latestEnhancedHeight, 621000)

        try await storage.set(619000, for: "latestUTXOFetchedHeight")
        let latestUTXOFetchedHeight = try await internalSyncProgress.latestUTXOFetchedHeight
        XCTAssertEqual(latestUTXOFetchedHeight, 619000)
    }

    func test__set__storeValue() async throws {
        try await internalSyncProgress.set(521000, .latestEnhancedHeight)
        let latestEnhancedHeight = try await storage.integer(for: "latestEnhancedHeight")
        XCTAssertEqual(latestEnhancedHeight, 521000)

        try await internalSyncProgress.set(519000, .latestUTXOFetchedHeight)
        let latestUTXOFetchedHeight = try await storage.integer(for: "latestUTXOFetchedHeight")
        XCTAssertEqual(latestUTXOFetchedHeight, 519000)
    }

    func test__whenUsingDefaultAliasKeysAreBackwardsCompatible() async throws {
        try await internalSyncProgress.set(630000, .latestDownloadedBlockHeight)
        try await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let latestDownloadedBlockHeight = try await storage.integer(for: InternalSyncProgress.Key.latestDownloadedBlockHeight.rawValue)
        let latestUTXOFetchedHeight = try await storage.integer(for: InternalSyncProgress.Key.latestUTXOFetchedHeight.rawValue)
        let latestEnhancedHeight = try await storage.integer(for: InternalSyncProgress.Key.latestEnhancedHeight.rawValue)
        XCTAssertEqual(latestDownloadedBlockHeight, 630000)
        XCTAssertEqual(latestUTXOFetchedHeight, 630000)
        XCTAssertEqual(latestEnhancedHeight, 630000)
    }

    func test__usingDifferentAliasesStoreValuesIndependently() async throws {
        let internalSyncProgress1 = InternalSyncProgress(alias: .custom("alias1"), storage: storage, logger: logger)
        try await internalSyncProgress1.set(121000, .latestDownloadedBlockHeight)
        try await internalSyncProgress1.set(121000, .latestUTXOFetchedHeight)
        try await internalSyncProgress1.set(121000, .latestEnhancedHeight)

        let internalSyncProgress2 = InternalSyncProgress(alias: .custom("alias2"), storage: storage, logger: logger)
        try await internalSyncProgress2.set(630000, .latestDownloadedBlockHeight)
        try await internalSyncProgress2.set(630000, .latestUTXOFetchedHeight)
        try await internalSyncProgress2.set(630000, .latestEnhancedHeight)

        let latestDownloadedBlockHeight1 = try await internalSyncProgress1.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh1 = try await internalSyncProgress1.load(.latestUTXOFetchedHeight)
        let latestEnhancedHeight1 = try await internalSyncProgress1.load(.latestEnhancedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight1, 121000)
        XCTAssertEqual(latestUTXOFetchedHeigh1, 121000)
        XCTAssertEqual(latestEnhancedHeight1, 121000)

        let latestDownloadedBlockHeight2 = try await internalSyncProgress2.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh2 = try await internalSyncProgress2.load(.latestUTXOFetchedHeight)
        let latestEnhancedHeight2 = try await internalSyncProgress2.load(.latestEnhancedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight2, 630000)
        XCTAssertEqual(latestUTXOFetchedHeigh2, 630000)
        XCTAssertEqual(latestEnhancedHeight2, 630000)
    }

    func test__migrateFromUserDefaults__withDefaultAlias() async throws {
        let userDefaults = UserDefaults.standard
        userDefaults.set(113000, forKey: InternalSyncProgress.Key.latestDownloadedBlockHeight.with(.default))
        userDefaults.set(114000, forKey: InternalSyncProgress.Key.latestEnhancedHeight.with(.default))
        userDefaults.set(115000, forKey: InternalSyncProgress.Key.latestUTXOFetchedHeight.with(.default))

        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 150000, alias: .default)

        let latestDownloadedBlockHeight = try await internalSyncProgress.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh = try await internalSyncProgress.load(.latestEnhancedHeight)
        let latestEnhancedHeight = try await internalSyncProgress.load(.latestUTXOFetchedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight, 113000)
        XCTAssertEqual(latestUTXOFetchedHeigh, 114000)
        XCTAssertEqual(latestEnhancedHeight, 115000)

        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestDownloadedBlockHeight.with(.default)), 0)
        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestEnhancedHeight.with(.default)), 0)
        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestUTXOFetchedHeight.with(.default)), 0)
    }

    func test__migrateFromUserDefaults__withAlias() async throws {
        let userDefaults = UserDefaults.standard
        let alias: ZcashSynchronizerAlias = .custom("something")
        internalSyncProgress = InternalSyncProgress(alias: alias, storage: storage, logger: logger)

        userDefaults.set(113000, forKey: InternalSyncProgress.Key.latestDownloadedBlockHeight.with(alias))
        userDefaults.set(114000, forKey: InternalSyncProgress.Key.latestEnhancedHeight.with(alias))
        userDefaults.set(115000, forKey: InternalSyncProgress.Key.latestUTXOFetchedHeight.with(alias))

        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 150000, alias: alias)

        let latestDownloadedBlockHeight = try await internalSyncProgress.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh = try await internalSyncProgress.load(.latestEnhancedHeight)
        let latestEnhancedHeight = try await internalSyncProgress.load(.latestUTXOFetchedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight, 113000)
        XCTAssertEqual(latestUTXOFetchedHeigh, 114000)
        XCTAssertEqual(latestEnhancedHeight, 115000)

        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestDownloadedBlockHeight.with(alias)), 0)
        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestEnhancedHeight.with(alias)), 0)
        XCTAssertEqual(userDefaults.integer(forKey: InternalSyncProgress.Key.latestUTXOFetchedHeight.with(alias)), 0)
    }
}
