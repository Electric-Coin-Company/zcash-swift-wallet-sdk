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

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping
final class SynchronizerTests: XCTestCase {
    let sendAmount = Zatoshi(1000)
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()
    var cancellables: [AnyCancellable] = []
    let processorEventHandler = CompactBlockProcessorEventHandler()

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

        let processorStoppedExpectation = XCTestExpectation(description: "ProcessorStopped Expectation")
        processorEventHandler.subscribe(
            to: await coordinator.synchronizer.blockProcessor.eventStream,
            expectations: [.stopped: processorStoppedExpectation]
        )

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

        wait(for: [syncStoppedExpectation, processorStoppedExpectation], timeout: 6, enforceOrder: true)

        XCTAssertEqual(coordinator.synchronizer.status, .stopped)
        let state = await coordinator.synchronizer.blockProcessor.state
        XCTAssertEqual(state, .stopped)
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
