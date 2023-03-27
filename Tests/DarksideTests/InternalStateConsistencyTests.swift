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

        self.coordinator = TestCoordinator.make(
            walletBirthday: birthday + 50, // don't use an exact birthday, users never do.
            network: network
        )
        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        wait { try await self.coordinator.stop() }
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
        coordinator = nil
        sdkSynchronizerSyncStatusHandler = nil
    }

    func testInternalStateIsConsistentWhenMigrating() async throws {
        sdkSynchronizerSyncStatusHandler.subscribe(
            to: coordinator.synchronizer.stateStream,
            expectations: [.stopped: firstSyncExpectation]
        )

        let fullSyncLength = 10000
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        sleep(1)

        // apply the height 
        try coordinator.applyStaged(blockheight: 664150)

        sleep(1)

        try await coordinator.sync(
            completion: { _ in
                XCTFail("shouldn't have completed")
            },
            error: handleError
        )

        let coordinator = self.coordinator!
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            Task(priority: .userInitiated) {
                await coordinator.synchronizer.stop()
            }
        }

        wait(for: [firstSyncExpectation], timeout: 2)

        let isSyncing = await coordinator.synchronizer.status.isSyncing
        let status = await coordinator.synchronizer.status
        XCTAssertFalse(isSyncing, "SDKSynchronizer shouldn't be syncing")
        XCTAssertEqual(status, .stopped)

        let internalSyncState = InternalSyncProgress(
            alias: .default,
            storage: UserDefaults.standard,
            logger: logger
        )

        let latestDownloadHeight = await internalSyncState.latestDownloadedBlockHeight
        let latestScanHeight = try await coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight()
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

        do {
            try await coordinator.sync(
                completion: { _ in
                    XCTAssertTrue(true)
                    secondSyncAttemptExpectation.fulfill()
                },
                error: { [weak self] error in
                    secondSyncAttemptExpectation.fulfill()
                    self?.handleError(error)
                }
            )
        } catch {
            handleError(error)
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
