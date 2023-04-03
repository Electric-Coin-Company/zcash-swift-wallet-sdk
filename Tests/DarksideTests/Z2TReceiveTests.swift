//
//  Z2TReceiveTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 8/4/21.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class Z2TReceiveTests: XCTestCase {
    let testRecipientAddress = "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz"
    let sendAmount: Int64 = 1000
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var foundTransactionsExpectation = XCTestExpectation(description: "found transactions")
    let branchID = "2bb40e60"
    let chainName = "main"
    var cancellables: [AnyCancellable] = []
    
    let network = DarksideWalletDNetwork()

    override func setUp() async throws {
        try await super.setUp()

        self.coordinator = try await TestCoordinator(walletBirthday: birthday, network: network)
        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        cancellables = []

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
    
    func subscribeToFoundTransactions() {
        coordinator.synchronizer.eventStream
            .filter { event in
                guard case .foundTransactions = event else { return false }
                return true
            }
            .sink(receiveValue: { [weak self] _ in self?.self.foundTransactionsExpectation.fulfill() })
            .store(in: &cancellables)
    }

    func testSendingZ2TWithMemoFails() async throws {
        subscribeToFoundTransactions()
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        /*
        2. applyStaged(received_Tx_height)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        /*
        3. sync up to received_Tx_height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    preTxExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }
        wait(for: [preTxExpectation, foundTransactionsExpectation], timeout: 5)
        
        let sendExpectation = XCTestExpectation(description: "sendToAddress")
        let sendAmount = Zatoshi(10000)
        /*
        4. create transaction
        */
        do {
            _ = try await coordinator.synchronizer.sendToAddress(
                spendingKey: coordinator.spendingKey,
                zatoshi: sendAmount,
                toAddress: try! Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "test transaction")
            )

            XCTFail("Should have thrown error")
        } catch {
            sendExpectation.fulfill()
            if case let SynchronizerError.generalError(message) = error {
                XCTAssertEqual(message, "Memos can't be sent to transparent addresses.")
            } else {
                // swiftlint:disable:next line_length
                XCTFail("expected SynchronizerError.genericError(\"Memos can't be sent to transparent addresses.\") but received \(error.localizedDescription)")
            }
            return
        }
    }

    func testFoundTransactions() async throws {
        subscribeToFoundTransactions()
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        /*
        2. applyStaged(received_Tx_height)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight)

        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        /*
        3. sync up to received_Tx_height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    preTxExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }
        wait(for: [preTxExpectation, foundTransactionsExpectation], timeout: 5)

        let sendExpectation = XCTestExpectation(description: "sendToAddress")
        var pendingEntity: PendingTransactionEntity?
        var testError: Error?
        let sendAmount = Zatoshi(10000)
        /*
        4. create transaction
        */
        do {
            let pending = try await coordinator.synchronizer.sendToAddress(
                spendingKey: coordinator.spendingKey,
                zatoshi: sendAmount,
                toAddress: try! Recipient(testRecipientAddress, network: self.network.networkType),
                memo: nil
            )
            pendingEntity = pending
            sendExpectation.fulfill()
        } catch {
            testError = error
        }

        wait(for: [sendExpectation], timeout: 12)

        guard pendingEntity != nil else {
            XCTFail("error sending to address. Error: \(String(describing: testError))")
            return
        }

        /*
        5. stage 10 empty blocks
        */
        try coordinator.stageBlockCreate(height: receivedTxHeight + 1, count: 10)

        let sentTxHeight = receivedTxHeight + 1

        /*
        6. stage sent tx at sentTxHeight
        */
        guard let sentTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("sent transaction not present on Darksidewalletd")
            return
        }

        try coordinator.stageTransaction(sentTx, at: sentTxHeight)

        /*
        6a. applyheight(sentTxHeight + 1 )
        */
        try coordinator.applyStaged(blockheight: sentTxHeight + 1)

        sleep(2)
        self.foundTransactionsExpectation = XCTestExpectation(description: "inbound expectation")

        /*
        7. sync to  sentTxHeight + 1
        */
        let sentTxSyncExpectation = XCTestExpectation(description: "sent tx sync expectation")

        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    let pMinedHeight = await synchronizer.pendingTransactions.first?.minedHeight
                    XCTAssertEqual(pMinedHeight, sentTxHeight)

                    sentTxSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [sentTxSyncExpectation, foundTransactionsExpectation], timeout: 5)
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
