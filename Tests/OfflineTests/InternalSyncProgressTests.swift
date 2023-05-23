//
//  InternalSyncProgressTests.swift
//  
//
//  Created by Michal Fousek on 30.11.2022.
//

@testable import TestUtils
import XCTest
@testable import ZcashLightClientKit

class InternalSyncProgressTests: XCTestCase {
    var storage: InternalSyncProgressMemoryStorage!
    var internalSyncProgress: InternalSyncProgress!

    override func setUp() {
        super.setUp()
        storage = InternalSyncProgressMemoryStorage()
        internalSyncProgress = InternalSyncProgress(alias: .default, storage: storage, logger: logger)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        storage = nil
        internalSyncProgress = nil
    }

    func test__trackedValuesAreHigherThanLatestHeight__nextStateIsWait() async throws {
        let latestHeight = 623000
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = await internalSyncProgress.computeNextState(
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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = await internalSyncProgress.computeNextState(
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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = await internalSyncProgress.computeNextState(
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
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        await internalSyncProgress.rewind(to: 640000)

        XCTAssertEqual(storage.integer(forKey: "latestEnhancedHeight"), 630000)
        XCTAssertEqual(storage.integer(forKey: "latestUTXOFetchedHeight"), 630000)
    }

    func test__rewindToHeightThatIsLowerThanTrackedHeight__rewindsToRewindHeight() async throws {
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        await internalSyncProgress.rewind(to: 620000)

        XCTAssertEqual(storage.integer(forKey: "latestEnhancedHeight"), 620000)
        XCTAssertEqual(storage.integer(forKey: "latestUTXOFetchedHeight"), 620000)
    }

    func test__get__returnsStoredValue() async throws {
        storage.set(621000, forKey: "latestEnhancedHeight")
        let latestEnhancedHeight = await internalSyncProgress.latestEnhancedHeight
        XCTAssertEqual(latestEnhancedHeight, 621000)

        storage.set(619000, forKey: "latestUTXOFetchedHeight")
        let latestUTXOFetchedHeight = await internalSyncProgress.latestUTXOFetchedHeight
        XCTAssertEqual(latestUTXOFetchedHeight, 619000)
    }

    func test__set__storeValue() async throws {
        await internalSyncProgress.set(521000, .latestEnhancedHeight)
        XCTAssertEqual(storage.integer(forKey: "latestEnhancedHeight"), 521000)

        await internalSyncProgress.set(519000, .latestUTXOFetchedHeight)
        XCTAssertEqual(storage.integer(forKey: "latestUTXOFetchedHeight"), 519000)
    }

    func test__whenUsingDefaultAliasKeysAreBackwardsCompatible() async {
        await internalSyncProgress.set(630000, .latestDownloadedBlockHeight)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        XCTAssertEqual(storage.integer(forKey: InternalSyncProgress.Key.latestDownloadedBlockHeight.rawValue), 630000)
        XCTAssertEqual(storage.integer(forKey: InternalSyncProgress.Key.latestUTXOFetchedHeight.rawValue), 630000)
        XCTAssertEqual(storage.integer(forKey: InternalSyncProgress.Key.latestEnhancedHeight.rawValue), 630000)
    }

    func test__usingDifferentAliasesStoreValuesIndependently() async {
        let internalSyncProgress1 = InternalSyncProgress(alias: .custom("alias1"), storage: storage, logger: logger)
        await internalSyncProgress1.set(121000, .latestDownloadedBlockHeight)
        await internalSyncProgress1.set(121000, .latestUTXOFetchedHeight)
        await internalSyncProgress1.set(121000, .latestEnhancedHeight)

        let internalSyncProgress2 = InternalSyncProgress(alias: .custom("alias2"), storage: storage, logger: logger)
        await internalSyncProgress2.set(630000, .latestDownloadedBlockHeight)
        await internalSyncProgress2.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress2.set(630000, .latestEnhancedHeight)

        let latestDownloadedBlockHeight1 = await internalSyncProgress1.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh1 = await internalSyncProgress1.load(.latestUTXOFetchedHeight)
        let latestEnhancedHeight1 = await internalSyncProgress1.load(.latestEnhancedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight1, 121000)
        XCTAssertEqual(latestUTXOFetchedHeigh1, 121000)
        XCTAssertEqual(latestEnhancedHeight1, 121000)

        let latestDownloadedBlockHeight2 = await internalSyncProgress2.load(.latestDownloadedBlockHeight)
        let latestUTXOFetchedHeigh2 = await internalSyncProgress2.load(.latestUTXOFetchedHeight)
        let latestEnhancedHeight2 = await internalSyncProgress2.load(.latestEnhancedHeight)
        XCTAssertEqual(latestDownloadedBlockHeight2, 630000)
        XCTAssertEqual(latestUTXOFetchedHeigh2, 630000)
        XCTAssertEqual(latestEnhancedHeight2, 630000)
    }
}
