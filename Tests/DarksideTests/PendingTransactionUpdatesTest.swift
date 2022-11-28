//
//  PendingTransactionUpdatesTest.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 7/17/20.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional
class PendingTransactionUpdatesTest: XCTestCase {
    // TODO: Parameterize this from environment?
    // swiftlint:disable:next line_length
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"
    // TODO: Parameterize this from environment
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"
    
    let sendAmount: Int64 = 1000
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
            walletBirthday: self.birthday,
            channelProvider: ChannelProvider(),
            network: self.network
        )

        try self.coordinator.reset(saplingActivation: 663150, branchID: "e9ff75a6", chainName: "main")
    }
    
    override func tearDownWithError() throws {
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
    
    @objc func handleReorg(_ notification: Notification) {
        guard
            let reorgHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight
        else {
            XCTFail("empty reorg notification")
            return
        }
        
        XCTAssertEqual(reorgHeight, expectedReorgHeight)
        reorgExpectation.fulfill()
    }
    
    func testPendingTransactionMinedHeightUpdated() async throws {
        /*
        1. create fake chain
        */
        LoggerProxy.info("1. create fake chain")
        
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: 663188)
        sleep(2)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        1a. sync to latest height
        */
        LoggerProxy.info("1a. sync to latest height")
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    firstSyncExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [firstSyncExpectation], timeout: 5)
        
        sleep(1)
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        
        /*
        2. send transaction to recipient address
        */
        LoggerProxy.info("2. send transaction to recipient address")
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                // swiftlint:disable:next force_unwrapping
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: Zatoshi(20000),
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard let pendingUnconfirmedTx = pendingEntity else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        
        XCTAssertFalse(
            pendingUnconfirmedTx.isConfirmed(currentHeight: 663188),
            "pending transaction evaluated as confirmed when it shouldn't"
        )
        XCTAssertFalse(
            pendingUnconfirmedTx.isMined,
            "pending transaction evaluated as mined when it shouldn't"
        )
        
        XCTAssertTrue(
            pendingUnconfirmedTx.isPending(currentHeight: 663188),
            "pending transaction evaluated as not pending when it should be"
        )

        /**
        3. getIncomingTransaction
        */
        LoggerProxy.info("3. getIncomingTransaction")
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
            return
        }
        
        let sentTxHeight: BlockHeight = 663189
        
        /*
        4. stage transaction at sentTxHeight
        */
        LoggerProxy.info("4. stage transaction at \(sentTxHeight)")
        try coordinator.stageBlockCreate(height: sentTxHeight)
        
        try coordinator.stageTransaction(incomingTx, at: sentTxHeight)

        /*
        5. applyHeight(sentTxHeight)
        */
        LoggerProxy.info("5. applyHeight(\(sentTxHeight))")
        try coordinator.applyStaged(blockheight: sentTxHeight)
        
        sleep(2)
        
        /*
        6. sync to latest height
        */
        LoggerProxy.info("6. sync to latest height")
        let secondSyncExpectation = XCTestExpectation(description: "after send expectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    secondSyncExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [secondSyncExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.pendingTransactions.count, 1)
        guard let afterStagePendingTx = coordinator.synchronizer.pendingTransactions.first else {
            return
        }
        
        /*
        6a. verify that there's a pending transaction with a mined height of sentTxHeight
        */
        LoggerProxy.info("6a. verify that there's a pending transaction with a mined height of \(sentTxHeight)")
        XCTAssertEqual(afterStagePendingTx.minedHeight, sentTxHeight)
        XCTAssertTrue(afterStagePendingTx.isMined, "pending transaction shown as unmined when it has been mined")
        XCTAssertTrue(afterStagePendingTx.isPending(currentHeight: sentTxHeight))
        
        /*
        7. stage 15  blocks from sentTxHeight
        */
        LoggerProxy.info("7. stage 15  blocks from \(sentTxHeight)")
        try coordinator.stageBlockCreate(height: sentTxHeight + 1, count: 15)
        sleep(2)
        let lastStageHeight = sentTxHeight + 14
        LoggerProxy.info("applyStaged(\(lastStageHeight))")
        try coordinator.applyStaged(blockheight: lastStageHeight)
        
        sleep(2)
        let syncToConfirmExpectation = XCTestExpectation(description: "sync to confirm expectation")
        
        /*
        8. last sync to latest height
        */
        LoggerProxy.info("last sync to latest height: \(lastStageHeight)")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    syncToConfirmExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [syncToConfirmExpectation], timeout: 6)
        var supposedlyPendingUnexistingTransaction: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { supposedlyPendingUnexistingTransaction = try coordinator.synchronizer.allPendingTransactions().first }())
        
        XCTAssertNil(supposedlyPendingUnexistingTransaction)
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReorg(_:)),
            name: .blockProcessorHandledReOrg,
            object: nil
        )
    }
}
