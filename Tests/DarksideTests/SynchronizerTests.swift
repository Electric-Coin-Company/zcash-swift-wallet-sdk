//
//  SynchronizerTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 9/16/22.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping type_body_length
final class SynchronizerTests: XCTestCase {

    // TODO: Parameterize this from environment?
    // swiftlint:disable:next line_length
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"

    // TODO: Parameterize this from environment
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"

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

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            seed: self.seedPhrase,
            walletBirthday:self.birthday + 50, //don't use an exact birthday, users never do.
            channelProvider: ChannelProvider(),
            network: self.network
        )

        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }

    @objc func handleReorg(_ notification: Notification) {
        guard
            let reorgHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight
        else {
            XCTFail("empty reorg notification")
            return
        }

        logger!.debug("--- REORG DETECTED \(reorgHeight)--- RewindHeight: \(rewindHeight)", file: #file, function: #function, line: #line)

        XCTAssertEqual(reorgHeight, expectedReorgHeight)
        reorgExpectation.fulfill()
    }

    func testSynchronizerStops() async throws {
        hookToReOrgNotification()

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
        processorStoppedExpectation.subscribe(to: .blockProcessorStopped, object: nil)

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

    func hookToReOrgNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleReorg(_:)), name: .blockProcessorHandledReOrg, object: nil)

    }
}
