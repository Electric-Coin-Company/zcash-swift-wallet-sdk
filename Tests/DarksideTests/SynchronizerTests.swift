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

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            seed: Environment.seedPhrase,
            walletBirthday: self.birthday + 50, // don't use an exact birthday, users never do.
            network: self.network
        )

        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)

        var stream: AnyPublisher<CompactBlockProcessor.Event, Never>!
        XCTestCase.wait { await stream = self.coordinator.synchronizer.blockProcessor.eventStream }
        stream
            .sink { [weak self] event in
                switch event {
                case .handledReorg: self?.handleReorg(event: event)
                default: break
                }
            }
            .store(in: &cancellables)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
        coordinator = nil
        cancellables = []
    }

    func handleReorg(event: CompactBlockProcessor.Event) {
        guard case let .handledReorg(reorgHeight, rewindHeight) = event else { return XCTFail("empty reorg notification") }

        logger!.debug("--- REORG DETECTED \(reorgHeight)--- RewindHeight: \(rewindHeight)", file: #file, function: #function, line: #line)

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
        syncStoppedExpectation.subscribe(to: .synchronizerStopped, object: nil)

        /*
        sync to latest height
        */
        try coordinator.sync(completion: { _ in
            XCTFail("Sync should have stopped")
        }, error: { error in
            _ = try? self.coordinator.stop()

            guard let testError = error else {
                XCTFail("failed with nil error")
                return
            }
            XCTFail("Failed with error: \(testError)")
        })

        try await Task.sleep(nanoseconds: 5_000_000_000)
        self.coordinator.synchronizer.stop()

        wait(for: [syncStoppedExpectation], timeout: 6)

        XCTAssertEqual(coordinator.synchronizer.status, .stopped)
        let state = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(state, .stopped)
    }

    @MainActor func testWipeCalledWhichSyncDoesntRun() async throws {
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
        try coordinator.sync(
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

    @MainActor func testWipeCalledWhileSyncRuns() async throws {
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
        try coordinator.sync(completion: { _ in
            XCTFail("Sync should have stopped")
        }, error: { error in
            _ = try? self.coordinator.stop()

            guard let testError = error else {
                XCTFail("failed with nil error")
                return
            }
            XCTFail("Failed with error: \(testError)")
        })

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
        XCTAssertFalse(fm.fileExists(atPath: coordinator.synchronizer.initializer.dataDbURL.path))
        XCTAssertFalse(fm.fileExists(atPath: coordinator.synchronizer.initializer.pendingDbURL.path))
        XCTAssertFalse(fm.fileExists(atPath: storage.blocksDirectory.path))

        let internalSyncProgress = InternalSyncProgress(storage: UserDefaults.standard)

        let latestDownloadedBlockHeight = await internalSyncProgress.load(.latestDownloadedBlockHeight)
        let latestEnhancedHeight = await internalSyncProgress.load(.latestEnhancedHeight)
        let latestUTXOFetchedHeight = await internalSyncProgress.load(.latestUTXOFetchedHeight)

        XCTAssertEqual(latestDownloadedBlockHeight, 0)
        XCTAssertEqual(latestEnhancedHeight, 0)
        XCTAssertEqual(latestUTXOFetchedHeight, 0)

        let blockProcessorState = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(blockProcessorState, .stopped)
    }

    func handleError(_ error: Error?) {
        _ = try? coordinator.stop()
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
