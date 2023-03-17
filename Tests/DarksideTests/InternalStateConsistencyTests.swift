//
//  InternalStateConsistencyTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 1/26/23.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class InternalStateConsistencyTests: XCTestCase {
    let sendAmount = Zatoshi(1000)
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()
    var sdkSynchronizerSyncStatusHandler: SDKSynchronizerSyncStatusHandler! = SDKSynchronizerSyncStatusHandler()

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            walletBirthday: birthday + 50, // don't use an exact birthday, users never do.
            network: network
        )
        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
        coordinator = nil
        sdkSynchronizerSyncStatusHandler = nil
    }

    @MainActor func testInternalStateIsConsistentWhenMigrating() async throws {
        sdkSynchronizerSyncStatusHandler.subscribe(
            to: coordinator.synchronizer.stateStream,
            expectations: [.stopped: firstSyncExpectation]
        )

        let fullSyncLength = 1000
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        sleep(1)

        // apply the height 
        try coordinator.applyStaged(blockheight: 664150)

        sleep(1)

        try coordinator.sync(
            completion: { _ in
                XCTFail("shouldn't have completed")
            },
            error: handleError
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.coordinator.synchronizer.stop()
        }

        wait(for: [firstSyncExpectation], timeout: 2)

        XCTAssertFalse(coordinator.synchronizer.status.isSyncing)
        XCTAssertEqual(coordinator.synchronizer.status, .stopped)

        let internalSyncState = InternalSyncProgress(storage: UserDefaults.standard)

        let latestDownloadHeight = await internalSyncState.latestDownloadedBlockHeight
        let latestScanHeight = try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight()
        let dbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDarksideCacheDb()!)
        try dbHandle.setUp()

        if latestDownloadHeight > latestScanHeight {
            try await coordinator.synchronizer.blockProcessor.migrateCacheDb(dbHandle.readWriteDb)

            let afterMigrationDownloadedHeight = await internalSyncState.latestDownloadedBlockHeight

            XCTAssertNotEqual(latestDownloadHeight, afterMigrationDownloadedHeight)
            XCTAssertEqual(latestScanHeight, afterMigrationDownloadedHeight)
        } else {
            try await coordinator.synchronizer.blockProcessor.migrateCacheDb(dbHandle.readWriteDb)

            let afterMigrationDownloadedHeight = await internalSyncState.latestDownloadedBlockHeight

            XCTAssertEqual(latestDownloadHeight, afterMigrationDownloadedHeight)
            XCTAssertEqual(latestScanHeight, afterMigrationDownloadedHeight)
        }

        XCTAssertFalse(FileManager.default.isReadableFile(atPath: dbHandle.readWriteDb.path))
        
        // clear to simulate a clean slate from the FsBlockDb
        try await coordinator.synchronizer.blockProcessor.storage.clear()

        // Now let's resume scanning and see how it goes.
        let secondSyncAttemptExpectation = XCTestExpectation(description: "second sync attempt")

        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { _ in
                        XCTAssertTrue(true)
                        secondSyncAttemptExpectation.fulfill()
                        continuation.resume()
                    },
                    error: { error in
                        secondSyncAttemptExpectation.fulfill()
                        guard let error else {
                            XCTFail("there was an unknown error")
                            continuation.resume()
                            return
                        }
                        continuation.resume(throwing: error)
                    }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [secondSyncAttemptExpectation], timeout: 10)
    }

    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
