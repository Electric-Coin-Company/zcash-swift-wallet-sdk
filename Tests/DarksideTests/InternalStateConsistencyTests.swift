//
//  InternalStateConsistencyTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 1/26/23.
//
// swiftlint:disable:all implicitly_unwrapped_optional force_unwrapping
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit
final class InternalStateConsistencyTests: XCTestCase {
    // TODO: [#715] Parameterize this from environment, https://github.com/zcash/ZcashLightClientKit/issues/715
    // swiftlint:disable:next line_length
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"

    // TODO: [#715] Parameterize this from environment, https://github.com/zcash/ZcashLightClientKit/issues/715
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"

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
    var firstSyncContinuation: CheckedContinuation<(), Error>?
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            seed: seedPhrase,
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
    }

    func testInternalStateIsConsistentWhenMigrating() async throws {
        NotificationCenter.default.addObserver(self, selector: #selector(self.processorStopped(_:)), name: .blockProcessorStopped, object: nil)

        let fullSyncLength = 1000
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        sleep(1)

        // apply the height 
        try coordinator.applyStaged(blockheight: 664150)

        sleep(1)

        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { _ in
                        XCTFail("shouldn't have completed")
                        continuation.resume()
                    }, error: { error in
                        guard let error else {
                            XCTFail("there was an unknown error")
                            continuation.resume()
                            return
                        }
                        continuation.resume(throwing: error)
                    }
                )

                self.firstSyncContinuation = continuation
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self.coordinator.synchronizer.stop()
                }
            } catch {
                continuation.resume(throwing: error)
            }
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

    @objc func processorStopped(_ notification: Notification) {
        firstSyncContinuation?.resume()
        self.firstSyncExpectation.fulfill()
    }
}
