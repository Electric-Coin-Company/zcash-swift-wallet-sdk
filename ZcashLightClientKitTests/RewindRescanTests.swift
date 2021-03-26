//
//  XCTRewindRescanTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/25/21.
//

import XCTest
@testable import ZcashLightClientKit
class RewindRescanTests: XCTestCase {
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" //TODO: Parameterize this from environment?
    
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a" //TODO: Parameterize this from environment
    
    let sendAmount: Int64 = 1000
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation: XCTestExpectation = XCTestExpectation(description: "reorg")
    override func setUpWithError() throws {
        
        coordinator = try TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
        try coordinator.reset(saplingActivation: 663150)
    }
    
    override func tearDownWithError() throws {
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }

    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
    
    func testBirthdayRescan() throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 50)
        let initialVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let initialTotalBalance = coordinator.synchronizer.initializer.getBalance()
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            firstSyncExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [firstSyncExpectation], timeout: 12)
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > ZcashSDK.defaultFee())
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to birthday
        try coordinator.synchronizer.rewind(.birthday)
        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight(),self.birthday)
        
        // check that the balance is cleared
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(initialTotalBalance, coordinator.synchronizer.initializer.getBalance())
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try coordinator.sync(completion: { (synchronizer) in
            secondScanExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
        
    }
    
    
    func testRescanToHeight() throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 50)
        let initialVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let initialTotalBalance = coordinator.synchronizer.initializer.getBalance()
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            firstSyncExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [firstSyncExpectation], timeout: 12)
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > ZcashSDK.defaultFee())
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to birthday
        let targetHeight: BlockHeight = 663160
        try coordinator.synchronizer.rewind(.height(blockheight: targetHeight))
        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight(),targetHeight)
        
        // check that the balance is cleared
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(initialTotalBalance, coordinator.synchronizer.initializer.getBalance())
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try coordinator.sync(completion: { (synchronizer) in
            secondScanExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
        
    }

    func testRescanToTransaction() throws {
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 50)
      
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            firstSyncExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [firstSyncExpectation], timeout: 12)
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance = coordinator.synchronizer.initializer.getBalance()
        // 2 check that there are no unconfirmed funds
        XCTAssertTrue(verifiedBalance > ZcashSDK.defaultFee())
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to transaction
        guard let transaction = try coordinator.synchronizer.allClearedTransactions().first else {
            XCTFail("failed to get a transaction to rewind to")
            return
        }

        try coordinator.synchronizer.rewind(.transaction(transaction.transactionEntity))

        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.synchronizer.initializer.transactionRepository.lastScannedHeight(),transaction.transactionEntity.anchor)
        
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try coordinator.sync(completion: { (synchronizer) in
            secondScanExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
        
    }
    
    func testRewindAfterSendingTransaction() throws {
        let notificationHandler = SDKSynchonizerListener()
        let foundTransactionsExpectation = XCTestExpectation(description: "found transactions expectation")
        let transactionMinedExpectation = XCTestExpectation(description: "transaction mined expectation")
        
        // 0 subscribe to updated transactions events
        notificationHandler.subscribeToSynchronizer(coordinator.synchronizer)
        // 1 sync and get spendable funds
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight + 10)
        
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            firstSyncExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [firstSyncExpectation], timeout: 12)
        // 2 check that there are no unconfirmed funds
        
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance = coordinator.synchronizer.initializer.getBalance()
        XCTAssertTrue(verifiedBalance > ZcashSDK.defaultFee())
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        let maxBalance = verifiedBalance - Int64(ZcashSDK.defaultFee())
        
        // 3 create a transaction for the max amount possible
        // 4 send the transaction
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        var pendingTx: PendingTransactionEntity?
        coordinator.synchronizer.sendToAddress(spendingKey: spendingKey,
                                               zatoshi: maxBalance,
                                               toAddress: testRecipientAddress,
                                               memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let error):
                XCTFail("sendToAddress failed: \(error)")
            case .success(let transaction):
                pendingTx = transaction
            }
            self.sentTransactionExpectation.fulfill()
        }
        wait(for: [sentTransactionExpectation], timeout: 20)
        guard let pendingTx = pendingTx else {
            XCTFail("transaction creation failed")
            return
        }
        
        notificationHandler.synchronizerMinedTransaction = { tx in
            XCTAssertNotNil(tx.rawTransactionId)
            XCTAssertNotNil(pendingTx.rawTransactionId)
            XCTAssertEqual(tx.rawTransactionId, pendingTx.rawTransactionId)
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
            let foundTx = txs.first(where: { $0.rawTransactionId ==  pendingTx.rawTransactionId})
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
        
        try coordinator.sync(completion: { (synchronizer) in
            let p = synchronizer.pendingTransactions.first(where: {$0.rawTransactionId == pendingTx.rawTransactionId})
            XCTAssertNotNil(p, "pending transaction should have been mined by now")
            XCTAssertTrue(p?.isMined ?? false)
            XCTAssertEqual(p?.minedHeight, sentTxHeight)
            mineExpectation.fulfill()
            
        }, error: { (error) in
            guard let e = error else {
                XCTFail("unknown error syncing after sending transaction")
                return
            }
            
            XCTFail("Error: \(e)")
        })
        
        wait(for: [mineExpectation, transactionMinedExpectation, foundTransactionsExpectation], timeout: 5)
        
        // 7 advance to confirmation
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 10)
        
        sleep(2)
        
        // rewind 5 blocks prior to sending
        
        try coordinator.synchronizer.rewind(.height(blockheight: sentTxHeight - 5))
        
        guard let np = try coordinator.synchronizer.allPendingTransactions().first(where: { $0.rawTransactionId == pendingTx.rawTransactionId}) else {
            XCTFail("sent pending transaction not found after rewind")
            return
        }
        
        XCTAssertFalse(np.isMined)
        let confirmExpectation = XCTestExpectation(description: "confirm expectation")
        notificationHandler.transactionsFound = { txs in
            XCTAssertEqual(txs.count, 1)
            guard let t = txs.first else {
                XCTFail("should have found sent transaction but didn't")
                return
            }
            XCTAssertEqual(t.rawTransactionId, pendingTx.rawTransactionId,"should have mined sent transaction but didn't")
        }
        notificationHandler.synchronizerMinedTransaction = { tx in
            XCTFail("We shouldn't find any mined transactions at this point but found \(tx)")
        }
        try coordinator.sync(completion: { synchronizer in
            confirmExpectation.fulfill()
        }, error: { e in
            self.handleError(e)
        })
        
        wait(for: [confirmExpectation], timeout: 10)
        
        let confirmedPending = try coordinator.synchronizer.allPendingTransactions().first(where: { $0.rawTransactionId == pendingTx.rawTransactionId})
        
        XCTAssertNil(confirmedPending, "pending, now confirmed transaction found")
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), 0)
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), 0)
    }
}
