//
//  NetworkUpgradeTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 10/30/20.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional type_body_length force_unwrapping
class NetworkUpgradeTests: XCTestCase {
    let activationHeight: BlockHeight = 1028500
    let spendingKey =
        // swiftlint:disable:next line_length
        "secret-extended-key-test1qv2vf437qqqqpqpfc0arpv55ncq33p2p895hlcx0ra6d0g739v93luqdjpxun3kt050j9qnrqjyp8d7fdxgedfyxpjmuyha2ulxa6hmqvm2gnvuc3tvs3enpxwuz768qfkd286vr3jgyrgr5ddx2ukrdl95ak3tzqylzjeqw3pnmgtmwsvemrj3sk6vqgwxm9khlv46wccn33ayw52prr233ea069c9u8m3839dvw30sdf6k32xddhpte6p6qsuxval6usyh6lr55pgypkgtz"

    // TODO: Parameterize this from environment
    let testRecipientAddress = "ztestsapling12k9m98wmpjts2m56wc60qzhgsfvlpxcwah268xk5yz4h942sd58jy3jamqyxjwums6hw7kfa4cc"
    let sendAmount = Zatoshi(1000)
    let branchID = "2bb40e60"
    let chainName = "main"

    var birthday: BlockHeight = 1013250
    var coordinator: TestCoordinator!
    var network = ZcashNetworkBuilder.network(for: .testnet)
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try coordinator.reset(saplingActivation: birthday, branchID: branchID, chainName: chainName)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }

    /**
    Given that a wallet had funds prior to activation it can spend them after activation
    */
    func testSpendPriorFundsAfterActivation() async throws {
        try FakeChainBuilder.buildChain(
            darksideWallet: coordinator.service,
            birthday: birthday,
            networkActivationHeight: activationHeight,
            branchID: branchID,
            chainName: chainName,
            length: 15300
        )
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight - ZcashSDK.defaultStaleTolerance)
        sleep(5)
        
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
        wait(for: [firstSyncExpectation], timeout: 120)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        guard verifiedBalance > network.constants.defaultFee(for: activationHeight) else {
            XCTFail("not enough balance to continue test")
            return
        }
    
        try coordinator.applyStaged(blockheight: activationHeight + 1)
        sleep(2)
       
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        let spendAmount = Zatoshi(10000)

        /*
        send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: spendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
                )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard pendingEntity != nil else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }

        /*
        getIncomingTransaction
        */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
            return
        }
        
        let sentTxHeight: BlockHeight = activationHeight + 2
   
        /*
        stage transaction at sentTxHeight
        */
        try coordinator.stageTransaction(incomingTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: activationHeight + 20)
        sleep(1)
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    afterSendExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [afterSendExpectation], timeout: 10)
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), verifiedBalance - spendAmount)
    }
    
    /**
    Given that a wallet receives funds after activation it can spend them when confirmed
    */
    func testSpendPostActivationFundsAfterConfirmation() async throws {
        try FakeChainBuilder.buildChainPostActivationFunds(
            darksideWallet: coordinator.service,
            birthday: birthday,
            networkActivationHeight: activationHeight,
            length: 15300
        )
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight + 10)
        sleep(3)
        
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
        
        wait(for: [firstSyncExpectation], timeout: 120)
        guard try !coordinator.synchronizer.allReceivedTransactions().filter({ $0.minedHeight > activationHeight }).isEmpty else {
            XCTFail("this test requires funds received after activation height")
            return
        }
        
        try coordinator.applyStaged(blockheight: activationHeight + 20)
        sleep(2)
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        let spendAmount = Zatoshi(10000)

        /*
        send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: spendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard pendingEntity != nil else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        
        try coordinator.applyStaged(blockheight: activationHeight + 1 + 10)
        
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    afterSendExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [afterSendExpectation], timeout: 10)
    }

    /**
    Given that a wallet sends funds some between (activation - expiry_height) and activation, those funds are shown as sent if mined.
    */
    func testSpendMinedSpendThatExpiresOnActivation() async throws {
        try FakeChainBuilder.buildChain(
            darksideWallet: coordinator.service,
            birthday: birthday,
            networkActivationHeight: activationHeight,
            branchID: branchID,
            chainName: chainName,
            length: 15300
        )
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight - 10)
        sleep(3)
        
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
        
        wait(for: [firstSyncExpectation], timeout: 120)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: activationHeight))
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        let spendAmount = Zatoshi(10000)

        /*
        send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: spendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard let pendingTx = pendingEntity else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        
        /*
        getIncomingTransaction
        */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
            return
        }
        
        let sentTxHeight: BlockHeight = activationHeight - 5
        
        /*
        stage transaction at sentTxHeight
        */
        try coordinator.stageTransaction(incomingTx, at: sentTxHeight)
        
        try coordinator.applyStaged(blockheight: activationHeight + 5)
        sleep(2)
        
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    afterSendExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [afterSendExpectation], timeout: 10)
        
        guard
            let confirmedTx = try coordinator.synchronizer.allConfirmedTransactions(from: nil, limit: Int.max)?
                .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        else {
            XCTFail("the sent transaction is not listed as a confirmed transaction")
            return
        }
        
        XCTAssertEqual(confirmedTx.minedHeight, sentTxHeight)
    }
    
    /**
    Given that a wallet sends funds somewhere between (activation - expiry_height) and activation, those funds are available if  expired after expiration height.
    */
    func testExpiredSpendAfterActivation() async throws {
        try FakeChainBuilder.buildChain(
            darksideWallet: coordinator.service,
            birthday: birthday,
            networkActivationHeight: activationHeight,
            branchID: branchID,
            chainName: chainName,
            length: 15300
        )
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        let offset = 5
        try coordinator.applyStaged(blockheight: activationHeight - 10)
        sleep(3)
        
        let verifiedBalancePreActivation: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        
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
        
        wait(for: [firstSyncExpectation], timeout: 120)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        guard verifiedBalance > network.constants.defaultFee(for: activationHeight) else {
            XCTFail("balance is not enough to continue with this test")
            return
        }
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        let spendAmount = Zatoshi(10000)

        /*
        send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: spendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard let pendingTx = pendingEntity else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        
        /*
        getIncomingTransaction
        */
        guard try coordinator.getIncomingTransactions()?.first != nil else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
            return
        }
            
        /*
        don't stage transaction
        */
        try coordinator.applyStaged(blockheight: activationHeight + offset)
        sleep(2)
        
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    afterSendExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [afterSendExpectation], timeout: 10)
        
        guard
            try coordinator.synchronizer.allConfirmedTransactions(from: nil, limit: Int.max)?
                .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId }) == nil
        else {
            XCTFail("the sent transaction should not be not listed as a confirmed transaction")
            return
        }
        
        XCTAssertEqual(verifiedBalancePreActivation, coordinator.synchronizer.initializer.getVerifiedBalance())
    }
    
    /**
    Given that a wallet has notes both received prior and after activation these can be combined to supply a larger amount spend.
    */
    func testCombinePreActivationNotesAndPostActivationNotesOnSpend() async throws {
        try FakeChainBuilder.buildChainMixedFunds(
            darksideWallet: coordinator.service,
            birthday: birthday,
            networkActivationHeight: activationHeight,
            branchID: branchID,
            chainName: chainName,
            length: 15300
        )
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight - 1)
        sleep(3)
        
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
        
        wait(for: [firstSyncExpectation], timeout: 120)
        
        let preActivationBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        
        try coordinator.applyStaged(blockheight: activationHeight + 30)
        sleep(2)
        
        let secondSyncExpectation = XCTestExpectation(description: "second sync")
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

        wait(for: [secondSyncExpectation], timeout: 10)
        guard try !coordinator.synchronizer.allReceivedTransactions().filter({ $0.minedHeight > activationHeight }).isEmpty else {
            XCTFail("this test requires funds received after activation height")
            return
        }
        let postActivationBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        
        XCTAssertTrue(preActivationBalance < postActivationBalance, "This test requires that funds post activation are greater that pre activation")
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        
        // spend all the funds
        let spendAmount = Zatoshi(
            postActivationBalance.amount - Int64(network.constants.defaultFee(for: activationHeight).amount)
        )
        
        /*
        send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKeys!.first!,
                zatoshi: spendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            self.handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 15)
        
        guard pendingEntity != nil else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), .zero)
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
