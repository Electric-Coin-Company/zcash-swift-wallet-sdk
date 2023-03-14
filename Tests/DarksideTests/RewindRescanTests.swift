//
//  XCTRewindRescanTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/25/21.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// FIXME: [#586] disabled until this is resolved https://github.com/zcash/ZcashLightClientKit/issues/586
class RewindRescanTests: XCTestCase {
    let sendAmount: Int64 = 1000
    let defaultLatestHeight: BlockHeight = 663175
    let branchID = "2bb40e60"
    let chainName = "main"

    var cancellables: [AnyCancellable] = []
    var birthday: BlockHeight = 663150
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    var network = ZcashNetworkBuilder.network(for: .mainnet)

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            walletBirthday: self.birthday,
            network: self.network
        )

        try self.coordinator.reset(saplingActivation: 663150, branchID: "e9ff75a6", chainName: "main")
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
    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        
        XCTFail("Failed with error: \(testError)")
    }
    
    func testBirthdayRescan() async throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 50)
        let initialVerifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let initialTotalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")

        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { _ in
                        firstSyncExpectation.fulfill()
                        continuation.resume()
                    },
                    error: self.handleError
                )
            } catch {
                continuation.resume(with: .failure(error))
            }
        }
        
        wait(for: [firstSyncExpectation], timeout: 12)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: defaultLatestHeight))
        XCTAssertEqual(verifiedBalance, totalBalance)

        let rewindExpectation = XCTestExpectation(description: "RewindExpectation")

        try await withCheckedThrowingContinuation { continuation in
            // rewind to birthday
            coordinator.synchronizer.rewind(.birthday)
                .sink(
                    receiveCompletion: { result in
                        rewindExpectation.fulfill()
                        switch result {
                        case .finished:
                            continuation.resume()

                        case let .failure(error):
                            XCTFail("Rewind failed with error: \(error)")
                            continuation.resume(with: .failure(error))
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }

        wait(for: [rewindExpectation], timeout: 2)

        // assert that after the new height is
        XCTAssertEqual(try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight(), self.birthday)
        
        // check that the balance is cleared
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(initialTotalBalance, coordinator.synchronizer.initializer.getBalance())
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { _ in
                        secondScanExpectation.fulfill()
                        continuation.resume()
                    },
                    error: self.handleError
                )
            } catch {
                continuation.resume(with: .failure(error))
            }
        }

        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
    }

    // FIXME [#789]: Fix test
    func testRescanToHeight() async throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChainWithTxsFarFromEachOther(
            darksideWallet: coordinator.service,
            branchID: branchID,
            chainName: chainName,
            length: 10000
        )
        let newChaintTip = defaultLatestHeight + 10000
        try coordinator.applyStaged(blockheight: newChaintTip)
        sleep(3)
        let initialVerifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { _ in
                    firstSyncExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [firstSyncExpectation], timeout: 20)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: defaultLatestHeight))
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to birthday
        let targetHeight: BlockHeight = newChaintTip - 8000
        let rewindHeight = ZcashRustBackend.getNearestRewindHeight(
            dbData: coordinator.databases.dataDB,
            height: Int32(targetHeight),
            networkType: network.networkType
        )

        let rewindExpectation = XCTestExpectation(description: "RewindExpectation")

        try await withCheckedThrowingContinuation { continuation in
            coordinator.synchronizer.rewind(.height(blockheight: targetHeight))
                .sink(
                    receiveCompletion: { result in
                        rewindExpectation.fulfill()
                        switch result {
                        case .finished:
                            continuation.resume()

                        case let .failure(error):
                            XCTFail("Rewind failed with error: \(error)")
                            continuation.resume(with: .failure(error))
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }

        wait(for: [rewindExpectation], timeout: 2)

        guard rewindHeight > 0 else {
            XCTFail("get nearest height failed error: \(ZcashRustBackend.getLastError() ?? "null")")
            return
        }

        // check that the balance is cleared
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())

        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { _ in
                    secondScanExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [secondScanExpectation], timeout: 20)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
        
        // try to spend the funds
        let sendExpectation = XCTestExpectation(description: "after rewind expectation")
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: coordinator.spendingKey,
                zatoshi: Zatoshi(1000),
                toAddress: try! Recipient(Environment.testRecipientAddress, network: .mainnet),
                memo: .empty
            )
            XCTAssertEqual(Zatoshi(1000), pendingTx.value)
            sendExpectation.fulfill()
        } catch {
            XCTFail("sending fail: \(error)")
        }
        wait(for: [sendExpectation], timeout: 15)
    }

    // FIX [#790]: Fix tests
    @MainActor func testRescanToTransaction() async throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 50)
      
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try coordinator.sync(
            completion: { _ in
                firstSyncExpectation.fulfill()
            },
            error: handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 12)
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: defaultLatestHeight))
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to transaction
        guard let transaction = try coordinator.synchronizer.allClearedTransactions().first else {
            XCTFail("failed to get a transaction to rewind to")
            return
        }

        let rewindExpectation = XCTestExpectation(description: "RewindExpectation")

        try await withCheckedThrowingContinuation { continuation in
            coordinator.synchronizer.rewind(.transaction(transaction))
                .sink(
                    receiveCompletion: { result in
                        rewindExpectation.fulfill()
                        switch result {
                        case .finished:
                            continuation.resume()

                        case let .failure(error):
                            XCTFail("Rewind failed with error: \(error)")
                            continuation.resume(with: .failure(error))
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }

        wait(for: [rewindExpectation], timeout: 2)

        // assert that after the new height is lower or same as transaction, rewind doesn't have to be make exactly to transaction height, it can
        // be done to nearest height provided by rust
        XCTAssertLessThanOrEqual(
            try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight(),
            transaction.anchor(network: network) ?? -1
        )
        
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try coordinator.sync(
            completion: { _ in
                secondScanExpectation.fulfill()
            },
            error: handleError
        )
        
        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
    }

    // FIXME [#791]: Fix test
    func disabled_testRewindAfterSendingTransaction() async throws {
        let notificationHandler = SDKSynchonizerListener()
        let foundTransactionsExpectation = XCTestExpectation(description: "found transactions expectation")
        let transactionMinedExpectation = XCTestExpectation(description: "transaction mined expectation")
        
        // 0 subscribe to updated transactions events
        notificationHandler.subscribeToSynchronizer(coordinator.synchronizer)
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 10)
        
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { _ in
                    firstSyncExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [firstSyncExpectation], timeout: 12)
        // 2 check that there are no unconfirmed funds
        
        let verifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        XCTAssertTrue(verifiedBalance > network.constants.defaultFee(for: defaultLatestHeight))
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        let maxBalance = verifiedBalance - network.constants.defaultFee(for: defaultLatestHeight)
        
        // 3 create a transaction for the max amount possible
        // 4 send the transaction
        let spendingKey = coordinator.spendingKey
        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: maxBalance,
                toAddress: try! Recipient(Environment.testRecipientAddress, network: .mainnet),
                memo: try Memo(string: "test send \(self.description) \(Date().description)")
            )
            pendingTx = transaction
            self.sentTransactionExpectation.fulfill()
        } catch {
            XCTFail("sendToAddress failed: \(error)")
        }
        wait(for: [sentTransactionExpectation], timeout: 20)
        guard let pendingTx = pendingTx else {
            XCTFail("transaction creation failed")
            return
        }
        
        notificationHandler.synchronizerMinedTransaction = { transaction in
            XCTAssertNotNil(transaction.rawTransactionId)
            XCTAssertNotNil(pendingTx.rawTransactionId)
            XCTAssertEqual(transaction.rawTransactionId, pendingTx.rawTransactionId)
            transactionMinedExpectation.fulfill()
        }
        
        // 5 apply to height
        // 6 mine the block
        guard let rawTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction after")
            return
        }
        
        let latestHeight = try coordinator.latestHeight()
        let sentTxHeight = latestHeight + 1
        
        notificationHandler.transactionsFound = { txs in
            let foundTx = txs.first(where: { $0.rawID == pendingTx.rawTransactionId })
            XCTAssertNotNil(foundTx)
            XCTAssertEqual(foundTx?.minedHeight, sentTxHeight)
            
            foundTransactionsExpectation.fulfill()
        }
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 100)
        sleep(1)
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight)
        sleep(2)
        
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
                        let pendingTransaction = synchronizer.pendingTransactions
                            .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
                        XCTAssertNotNil(pendingTransaction, "pending transaction should have been mined by now")
                        XCTAssertTrue(pendingTransaction?.isMined ?? false)
                        XCTAssertEqual(pendingTransaction?.minedHeight, sentTxHeight)
                        mineExpectation.fulfill()
                        continuation.resume()
                    }, error: { error in
                        guard let error else {
                            XCTFail("unknown error syncing after sending transaction")
                            return
                        }
                    
                        XCTFail("Error: \(error)")
                    }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [mineExpectation, transactionMinedExpectation, foundTransactionsExpectation], timeout: 5)
        
        // 7 advance to confirmation
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 10)
        
        sleep(2)

        let rewindExpectation = XCTestExpectation(description: "RewindExpectation")

        try await withCheckedThrowingContinuation { continuation in
            // rewind 5 blocks prior to sending
            coordinator.synchronizer.rewind(.height(blockheight: sentTxHeight - 5))
                .sink(
                    receiveCompletion: { result in
                        rewindExpectation.fulfill()
                        switch result {
                        case .finished:
                            continuation.resume()

                        case let .failure(error):
                            XCTFail("Rewind failed with error: \(error)")
                            continuation.resume(with: .failure(error))
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }

        wait(for: [rewindExpectation], timeout: 2)

        guard
            let pendingEntity = try coordinator.synchronizer.allPendingTransactions()
                .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        else {
            XCTFail("sent pending transaction not found after rewind")
            return
        }
        
        XCTAssertFalse(pendingEntity.isMined)

        let confirmExpectation = XCTestExpectation(description: "confirm expectation")
        notificationHandler.transactionsFound = { txs in
            XCTAssertEqual(txs.count, 1)
            guard let transaction = txs.first else {
                XCTFail("should have found sent transaction but didn't")
                return
            }
            XCTAssertEqual(transaction.rawID, pendingTx.rawTransactionId, "should have mined sent transaction but didn't")
        }

        notificationHandler.synchronizerMinedTransaction = { transaction in
            XCTFail("We shouldn't find any mined transactions at this point but found \(transaction)")
        }

        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { _ in
                    confirmExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [confirmExpectation], timeout: 10)
        
        let confirmedPending = try coordinator.synchronizer.allPendingTransactions()
            .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        
        XCTAssertNil(confirmedPending, "pending, now confirmed transaction found")
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), .zero)
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), .zero)
    }
}
