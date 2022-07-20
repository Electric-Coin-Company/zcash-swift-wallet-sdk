//
//  SwitchServerTests.swift
//  
//
//  Created by Francisco Gindre on 7/20/22.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class SwitchServerTests: XCTestCase {
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
        coordinator = try TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider(),
            network: network
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

    func testChangingServersFailsWithSaplingActivation() throws {

        let fullSyncLength = 100_000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(10)

        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        sync to latest height
        */
        try coordinator.sync(completion: { _ in
            firstSyncExpectation.fulfill()
        }, error: { error in
            _ = try? self.coordinator.stop()
            firstSyncExpectation.fulfill()
            guard let testError = error else {
                XCTFail("failed with nil error")
                return
            }
            XCTFail("Failed with error: \(testError)")
        })

        sleep(3)

        let expectedEndpoint = LightWalletEndpoint(address: "mainnet.lightwalletd.com", port: 9067)

        let switchExpectation = XCTestExpectation(description: "server switch expectation")

        coordinator.synchronizer.switchToEndpoint(expectedEndpoint) { switchResult in
            switchExpectation.fulfill()
            switch switchResult {
            case .failure(let error):
                guard let processorError = error as? CompactBlockProcessorError else {
                    XCTFail("Switching Server should have failed with error CompactBlockProcessorError.saplingActivationMismatch but found \(error)")
                    return
                }

                if case let CompactBlockProcessorError.saplingActivationMismatch(expected, found) = processorError {
                    XCTAssertEqual(expected, 663150)
                    XCTAssertEqual(found, 419200)
                }
            case .success:
                XCTFail("Switching Server should have failed with error \(CompactBlockProcessorError.saplingActivationMismatch(expected: 663150, found: 419200))")
            }
        }

        wait(for: [switchExpectation], timeout: 2)
        
    }

    func testSwitchingToWrongNetworkShouldFail() throws {
        let fullSyncLength = 100_000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(10)

        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        sync to latest height
        */
        try coordinator.sync(completion: { _ in
            firstSyncExpectation.fulfill()
        }, error: { error in
            _ = try? self.coordinator.stop()
            firstSyncExpectation.fulfill()
            guard let testError = error else {
                XCTFail("failed with nil error")
                return
            }
            XCTFail("Failed with error: \(testError)")
        })

        sleep(3)

        coordinator.synchronizer.stop()

        try coordinator.service.reset(saplingActivation: 663150, branchID: self.branchID, chainName: "test")

        sleep(1)

        let switchExpectation = XCTestExpectation(description: "server switch expectation")

        let newEndpoint = LightWalletEndpoint(address: "127.0.0.1", port: 9067) // make the addresses not match. wink wink

        coordinator.synchronizer.switchToEndpoint(newEndpoint) { switchResult in
            switchExpectation.fulfill()
            switch switchResult {
            case .failure(let error):
                guard let processorError = error as? CompactBlockProcessorError else {
                    XCTFail("Switching Server should have failed with error CompactBlockProcessorError.saplingActivationMismatch but found \(error)")
                    return
                }

                if case let CompactBlockProcessorError.networkMismatch(expected, found) = processorError {
                    XCTAssertEqual(expected, .mainnet)
                    XCTAssertEqual(found, .testnet)
                }
            case .success:
                XCTFail("Switching Server should have failed with error \(CompactBlockProcessorError.saplingActivationMismatch(expected: 663150, found: 419200))")
            }
        }

        wait(for: [switchExpectation], timeout: 10)
    }

    func testSwitchingToWrongConsensusBranchIDShouldFail() throws {
        let fullSyncLength = 100_000

        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)

        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)

        sleep(10)

        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        sync to latest height
        */
        try coordinator.sync(completion: { _ in
            firstSyncExpectation.fulfill()
        }, error: { error in
            _ = try? self.coordinator.stop()
            firstSyncExpectation.fulfill()
            guard let testError = error else {
                XCTFail("failed with nil error")
                return
            }
            XCTFail("Failed with error: \(testError)")
        })

        sleep(3)

        coordinator.synchronizer.stop()

        try coordinator.service.reset(saplingActivation: 663150, branchID: "d34db33f", chainName: self.chainName)

        sleep(1)

        let switchExpectation = XCTestExpectation(description: "server switch expectation")

        let newEndpoint = LightWalletEndpoint(address: "127.0.0.1", port: 9067) // make the addresses not match. wink wink

        coordinator.synchronizer.switchToEndpoint(newEndpoint) { switchResult in
            switchExpectation.fulfill()
            switch switchResult {
            case .failure(let error):
                guard let processorError = error as? CompactBlockProcessorError else {
                    XCTFail("Switching Server should have failed with error CompactBlockProcessorError.saplingActivationMismatch but found \(error)")
                    return
                }

                if case let CompactBlockProcessorError.wrongConsensusBranchId(expected, found) = processorError {
                    XCTAssertEqual(expected, ConsensusBranchID.fromString(self.branchID))
                    XCTAssertEqual(found, ConsensusBranchID.fromString("d34db33f"))
                }
            case .success:
                XCTFail("Switching Server should have failed with error \(CompactBlockProcessorError.saplingActivationMismatch(expected: 663150, found: 419200))")
            }
        }

        wait(for: [switchExpectation], timeout: 10)
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
