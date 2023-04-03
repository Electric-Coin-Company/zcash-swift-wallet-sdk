//
//  SynchronizerTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 9/16/22.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class SynchronizerTests: XCTestCase {
    let sendAmount = Zatoshi(1000)
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()
    var cancellables: [AnyCancellable] = []
    var sdkSynchronizerSyncStatusHandler: SDKSynchronizerSyncStatusHandler! = SDKSynchronizerSyncStatusHandler()

    override func setUp() async throws {
        try await super.setUp()

        // don't use an exact birthday, users never do.
        self.coordinator = try await TestCoordinator(walletBirthday: birthday + 50, network: network)
        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)

        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case .handledReorg: self?.handleReorg(event: event)
            default: break
            }
        }

        await self.coordinator.synchronizer.blockProcessor.updateEventClosure(identifier: "tests", closure: eventClosure)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        sdkSynchronizerSyncStatusHandler = nil
        cancellables = []

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }

    func handleReorg(event: CompactBlockProcessor.Event) {
        guard case let .handledReorg(reorgHeight, rewindHeight) = event else { return XCTFail("empty reorg notification") }

        logger.debug("--- REORG DETECTED \(reorgHeight)--- RewindHeight: \(rewindHeight)", file: #file, function: #function, line: #line)

        XCTAssertEqual(reorgHeight, expectedReorgHeight)
        reorgExpectation.fulfill()
    }

    func testSynchronizerStops() async throws {
        /*
        1. create fake chain
        */
        let fullSyncLength = 100_000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(10)

        let syncStoppedExpectation = XCTestExpectation(description: "SynchronizerStopped Expectation")
        sdkSynchronizerSyncStatusHandler.subscribe(
            to: coordinator.synchronizer.stateStream,
            expectations: [.stopped: syncStoppedExpectation]
        )

        /*
        sync to latest height
        */
        try await coordinator.sync(
            completion: { _ in
                XCTFail("Sync should have stopped")
            },
            error: self.handleError
        )

        try await Task.sleep(nanoseconds: 5_000_000_000)
        await self.coordinator.synchronizer.stop()

        wait(for: [syncStoppedExpectation], timeout: 6)

        let status = await coordinator.synchronizer.status
        XCTAssertEqual(status, .stopped)
        let state = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(state, .stopped)
    }

    // MARK: Wipe tests

    func testWipeCalledWhichSyncDoesntRun() async throws {
        /*
         create fake chain
         */
        let fullSyncLength = 1000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(2)

        let syncFinished = XCTestExpectation(description: "SynchronizerSyncFinished Expectation")

        /*
         sync to latest height
         */
        try await coordinator.sync(
            completion: { _ in
                syncFinished.fulfill()
            },
            error: handleError
        )

        wait(for: [syncFinished], timeout: 3)

        let wipeFinished = XCTestExpectation(description: "SynchronizerWipeFinished Expectation")

        /*
         Call wipe
         */
        coordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        wipeFinished.fulfill()

                    case .failure(let error):
                        XCTFail("Wipe should finish successfully. \(error)")
                    }
                },
                receiveValue: {
                    XCTFail("No no value should be received from wipe.")
                }
            )
            .store(in: &cancellables)

        wait(for: [wipeFinished], timeout: 1)

        /*
         Check that wipe cleared everything that is expected
         */
        await checkThatWipeWorked()
    }

    func testWipeCalledWhileSyncRuns() async throws {
        /*
         1. create fake chain
         */
        let fullSyncLength = 50_000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(5)

        /*
         Start sync
         */
        try await coordinator.sync(
            completion: { _ in
                XCTFail("Sync should have stopped")
            },
            error: self.handleError
        )

        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Just to be sure that blockProcessor is still syncing and that this test does what it should.
        let blockProcessorState = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(blockProcessorState, .syncing)

        let wipeFinished = XCTestExpectation(description: "SynchronizerWipeFinished Expectation")
        /*
         Call wipe
         */
        coordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        wipeFinished.fulfill()

                    case .failure(let error):
                        XCTFail("Wipe should finish successfully. \(error)")
                    }
                },
                receiveValue: {
                    XCTFail("No no value should be received from wipe.")
                }
            )
            .store(in: &cancellables)

        wait(for: [wipeFinished], timeout: 6)

        /*
         Check that wipe cleared everything that is expected
         */
        await checkThatWipeWorked()
    }

    private func checkThatWipeWorked() async {
        let storage = await self.coordinator.synchronizer.blockProcessor.storage as! FSCompactBlockRepository
        let fm = FileManager.default
        print(coordinator.synchronizer.initializer.dataDbURL.path)
        XCTAssertFalse(fm.fileExists(atPath: coordinator.synchronizer.initializer.pendingDbURL.path), "Pending DB should be deleted")
        XCTAssertFalse(fm.fileExists(atPath: coordinator.synchronizer.initializer.dataDbURL.path), "Data DB should be deleted.")
        XCTAssertTrue(fm.fileExists(atPath: storage.blocksDirectory.path), "FS Cache directory should exist")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: storage.blocksDirectory.path), [], "FS Cache directory should be empty")

        let internalSyncProgress = InternalSyncProgress(
            alias: .default,
            storage: UserDefaults.standard,
            logger: logger
        )

        let latestDownloadedBlockHeight = await internalSyncProgress.load(.latestDownloadedBlockHeight)
        let latestEnhancedHeight = await internalSyncProgress.load(.latestEnhancedHeight)
        let latestUTXOFetchedHeight = await internalSyncProgress.load(.latestUTXOFetchedHeight)

        XCTAssertEqual(latestDownloadedBlockHeight, 0, "internalSyncProgress latestDownloadedBlockHeight should be 0")
        XCTAssertEqual(latestEnhancedHeight, 0, "internalSyncProgress latestEnhancedHeight should be 0")
        XCTAssertEqual(latestUTXOFetchedHeight, 0, "internalSyncProgress latestUTXOFetchedHeight should be 0")

        let blockProcessorState = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(blockProcessorState, .stopped, "CompactBlockProcessor state should be stopped")

        let status = await coordinator.synchronizer.status
        XCTAssertEqual(status, .unprepared, "SDKSynchronizer state should be unprepared")
    }

    func handleError(_ error: Error?) async {
        _ = try? await coordinator.stop()
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }

    // MARK: Rewind tests

    func testRewindCalledWhileSyncRuns() async throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)

        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        let initialVerifiedBalance: Zatoshi = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let initialTotalBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")

        do {
            try await coordinator.sync(
                completion: { _ in
                    firstSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [firstSyncExpectation], timeout: 12)

        // Add more blocks to the chain so the long sync can start.
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: 10000)
        try coordinator.applyStaged(blockheight: birthday + 10000)

        sleep(2)

        do {
            // Start the long sync.
            try await coordinator.sync(
                completion: { _ in },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        // Wait 0.5 second and then start rewind while sync is in progress.
        let waitExpectation = XCTestExpectation()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }

        wait(for: [waitExpectation], timeout: 1)

        let verifiedBalance: Zatoshi = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let totalBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: defaultLatestHeight))
        XCTAssertEqual(verifiedBalance, totalBalance)

        let rewindExpectation = XCTestExpectation(description: "RewindExpectation")

        // rewind to birthday
        coordinator.synchronizer.rewind(.birthday)
            .sink(
                receiveCompletion: { result in
                    rewindExpectation.fulfill()
                    switch result {
                    case .finished:
                        break
                    case let .failure(error):
                        XCTFail("Rewind failed with error: \(error)")
                    }
                    rewindExpectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [rewindExpectation], timeout: 5)

        // assert that after the new height is
        let lastScannedHeight = try await coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight()
        XCTAssertEqual(lastScannedHeight, self.birthday)

        // check that the balance is cleared
        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(initialVerifiedBalance, expectedVerifiedBalance)
        XCTAssertEqual(initialTotalBalance, expectedBalance)
    }
}
