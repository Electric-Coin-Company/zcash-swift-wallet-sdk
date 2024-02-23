//
//  PaymentURIFulfillmentTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 2024-02-19
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class PaymentURIFulfillmentTests: ZcashTestCase {
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

    override func setUp() async throws {
        try await super.setUp()

        // don't use an exact birthday, users never do.
        self.coordinator = try await TestCoordinator(
            container: mockContainer,
            walletBirthday: birthday + 50,
            network: network
        )

        try await coordinator.reset(
            saplingActivation: 663150,
            startSaplingTreeSize: 128607,
            startOrchardTreeSize: 0,
            branchID: self.branchID,
            chainName: self.chainName
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        cancellables = []

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
    }

    /// Create a transaction from a ZIP-321 Payment URI
    /// Pre-condition: Wallet has funds
    ///
    /// Steps:
    /// 1. create fake chain
    /// 1a. sync to latest height
    /// 2. create proposal for PaymentURI
    /// 3. getIncomingTransaction
    /// 4. stage transaction at sentTxHeight
    /// 5. applyHeight(sentTxHeight)
    /// 6. sync to latest height
    /// 7. stage 20  blocks from sentTxHeight
    /// 8. applyHeight(sentTxHeight + 1) to cause a 1 block reorg
    /// 9. sync to latest height
    /// 10. applyHeight(sentTxHeight + 2)
    /// 10a. sync to latest height
    /// 11. applyheight(sentTxHeight + 25)
    func testPaymentToValidURIFulfillmentSucceeds() async throws {
        /*
        1. create fake chain
        */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)

        try coordinator.applyStaged(blockheight: 663188)
        sleep(2)

        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
        1a. sync to latest height
        */
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

        await fulfillment(of: [firstSyncExpectation], timeout: 5)

        sleep(1)

        let sendExpectation = XCTestExpectation(description: "send expectation")
        var proposal: ZcashTransaction.Overview?

        /*
        2. send transaction to recipient address
        */

        let memo = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg" // "This is a simple memo."
        let paymentURI = "zcash:\(Environment.testRecipientAddress)?amount=0.0002&memo=\(memo)&message=Thank%20you%20for%20your%20purchase&label=Your%20Purchase"

        do {
            let proposal = try await coordinator.synchronizer.proposefulfillingPaymentURI(
                paymentURI,
                accountIndex: 0
            )

            let transactions = try await coordinator.synchronizer.createProposedTransactions(
                proposal: proposal,
                spendingKey: coordinator.spendingKey
            )

            for try await tx in transactions {
                switch tx {
                case .grpcFailure(_, let error):
                    XCTFail("transaction failed to submit with error:\(error.localizedDescription)")
                    return
                case .success(txId: let txId):
                    continue
                case .submitFailure(txId: let txId, code: let code, description: let description):
                    XCTFail("transaction failed to submit with code: \(code) - description: \(description)")
                    return
                case .notAttempted(txId: let txId):
                    XCTFail("transaction not attempted")
                    return
                }
            }
            sendExpectation.fulfill()
        } catch {
            await handleError(error)
        }

        await fulfillment(of: [sendExpectation], timeout: 13)


        /**
        3. getIncomingTransaction
        */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try await coordinator.stop()
            return
        }

        let sentTxHeight: BlockHeight = 663189

        /*
        4. stage transaction at sentTxHeight
        */
        try coordinator.stageBlockCreate(height: sentTxHeight)

        try coordinator.stageTransaction(incomingTx, at: sentTxHeight)

        /*
        5. applyHeight(sentTxHeight)
        */
        try coordinator.applyStaged(blockheight: sentTxHeight)

        sleep(2)

        /*
        6. sync to latest height
        */
        let secondSyncExpectation = XCTestExpectation(description: "after send expectation")

        do {
            try await coordinator.sync(
                completion: { _ in
                    secondSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        await fulfillment(of: [secondSyncExpectation], timeout: 5)

        /*
        7. stage 20  blocks from sentTxHeight
        */
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 25)

        /*
        7a. stage sent tx to sentTxHeight + 2
        */
        try coordinator.stageTransaction(incomingTx, at: sentTxHeight + 2)

        /*
        8. applyHeight(sentTxHeight + 1) to cause a 1 block reorg
        */
        try coordinator.applyStaged(blockheight: sentTxHeight + 1)
        sleep(2)

        /*
        9. sync to latest height
        */
        self.expectedReorgHeight = sentTxHeight + 1
        let afterReorgExpectation = XCTestExpectation(description: "after reorg sync")

        do {
            try await coordinator.sync(
                completion: { _ in
                    afterReorgExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        await fulfillment(of: [afterReorgExpectation], timeout: 5)

        // TODO: [#1247] needs to review this to properly solve, https://github.com/zcash/ZcashLightClientKit/issues/1247

        /*
        10. applyHeight(sentTxHeight + 2)
        */
        try coordinator.applyStaged(blockheight: sentTxHeight + 2)
        sleep(2)

        let yetAnotherExpectation = XCTestExpectation(description: "after staging expectation")

        /*
        10a. sync to latest height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    yetAnotherExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        await fulfillment(of: [yetAnotherExpectation], timeout: 5)

        /*
        11. apply height(sentTxHeight + 25)
        */
        try coordinator.applyStaged(blockheight: sentTxHeight + 25)

        sleep(2)

        let thisIsTheLastExpectationIPromess = XCTestExpectation(description: "last sync")

        /*
        12. sync to latest height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    thisIsTheLastExpectationIPromess.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        await fulfillment(of: [thisIsTheLastExpectationIPromess], timeout: 5)
    }

    /// Attempt to create a transaction from an invalid ZIP-321 Payment URI and assert that fails
    /// Pre-condition: Wallet has funds
    ///
    /// Steps:
    /// 1. create fake chain
    /// 1a. sync to latest height
    /// 2. create proposal for PaymentURI
    /// 3. check that fails
    func testPaymentToInvalidURIFulfillmentFails() async throws {
        /*
         1. create fake chain
         */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)

        try coordinator.applyStaged(blockheight: 663188)
        sleep(2)

        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
         1a. sync to latest height
         */
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

        await fulfillment(of: [firstSyncExpectation], timeout: 5)

        sleep(1)

        /*
         2. send transaction to recipient address
         */

        let memo = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg" // "This is a simple memo."
        let paymentURI = "zcash:zecIsGreat17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a?amount=0.0002&memo=\(memo)&message=Thank%20you%20for%20your%20purchase&label=Your%20Purchase"

        do {
            let _ = try await coordinator.synchronizer.proposefulfillingPaymentURI(
                paymentURI,
                accountIndex: 0
            )

            XCTFail("`fulfillPaymentURI` should have failed")
        } catch ZcashError.rustProposeTransferFromURI {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Expected ZcashError.rustCreateToAddress but got \(error.localizedDescription)")
        }
    }

    func handleError(_ error: Error?) async {
        _ = try? await coordinator.stop()
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
