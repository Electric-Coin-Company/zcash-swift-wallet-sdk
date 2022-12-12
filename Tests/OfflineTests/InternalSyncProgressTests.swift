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

    var storage: InternalSyncProgressStorage!
    var internalSyncProgress: InternalSyncProgress!

    override func setUp() {
        super.setUp()
        storage = InternalSyncProgressMemoryStorage()
        internalSyncProgress = InternalSyncProgress(storage: storage)
    }

    func test__trackedValuesAreHigherThanLatestHeight__nextStateIsWait() async throws {
        let latestHeight = 623000
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: 630000)
        await internalSyncProgress.set(630000, .latestUTXOFetchedHeight)
        await internalSyncProgress.set(630000, .latestEnhancedHeight)

        let nextState = try await internalSyncProgress.computeNextState(
            latestBlockHeight: latestHeight,
            latestScannedHeight: 630000,
            walletBirthday: 600000
        )

        switch nextState {
        case let .processNewBlocks(ranges):
            XCTAssertEqual(ranges.downloadRange, 630001...640000)
            XCTAssertEqual(ranges.scanRange, 630001...640000)
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
}
