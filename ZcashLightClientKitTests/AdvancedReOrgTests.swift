//
//  AdvancedReOrgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/14/20.
//

import XCTest
@testable import ZcashLightClientKit
class AdvancedReOrgTests: XCTestCase {
    
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
    
    @objc func handleReorg(_ notification: Notification) {
        
        guard let reorgHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight
//            let rewindHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight
            else {
                XCTFail("empty reorg notification")
                return
        }
        
//        XCTAssertEqual(rewindHeight, expectedRewindHeight)
        XCTAssertEqual(reorgHeight, expectedReorgHeight)
        reorgExpectation.fulfill()
    }
    
    /*
     pre-condition: know balances before tx at received_Tx_height arrives
     1. Setup w/ default dataset
     2. applyStaged(received_Tx_height)
     3. sync up to received_Tx_height
     3a. verify that balance is previous balance + tx amount
     4. get that transaction hex encoded data
     5. stage 5 empty blocks w/heights received_Tx_height to received_Tx_height + 3
     6. stage tx at received_Tx_height + 3
     6a. applyheight(received_Tx_height + 1)
     7. sync to received_Tx_height + 1
     8. assert that reorg happened at received_Tx_height
     9. verify that balance equals initial balance
     10. sync up to received_Tx_height + 3
     11. verify that balance equals initial balance + tx amount
     */
    func testReOrgChangesInboundTxMinedHeight() throws {
        hookToReOrgNotification()
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service )
        var shouldContinue =  false
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        self.expectedReorgHeight = receivedTxHeight + 1
        
        /*
         precondition:know balances before tx at received_Tx_height arrives
         */
        try coordinator.applyStaged(blockheight: receivedTxHeight - 1)
        sleep(3)
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        var s: SDKSynchronizer?
        
        try coordinator.sync(completion: { (synchronizer) in
            s = synchronizer
            initialVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            initialTotalBalance = synchronizer.initializer.getBalance()
            preTxExpectation.fulfill()
            shouldContinue = true
        }, error: self.handleError)
        
        wait(for: [preTxExpectation], timeout: 5)
        
        guard shouldContinue else {
            XCTFail("pre receive sync failed")
            return
        }
        
        /*
         2. applyStaged(received_Tx_height)
         */
        
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        sleep(1)
        
        /*
         3. sync up to received_Tx_height
         */
        
        let receivedTxExpectation = XCTestExpectation(description: "received tx")
        var receivedTxTotalBalance = Int64(-1)
        var receivedTxVerifiedBalance = Int64(-1)
        
        try coordinator.sync(completion: { (synchronizer) in
            s = synchronizer
            receivedTxVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            receivedTxTotalBalance = synchronizer.initializer.getBalance()
            receivedTxExpectation.fulfill()
        }, error: self.handleError)
        sleep(2)
        wait(for: [receivedTxExpectation], timeout: 5)
        
        guard let syncedSynchronizer = s else {
            XCTFail("nil synchronizer")
            return
        }
        sleep(5)
        guard let receivedTx = syncedSynchronizer.receivedTransactions.first, receivedTx.minedHeight == receivedTxHeight else {
            XCTFail("did not receive transaction")
            return
        }
        
        
        /*
         3a. verify that balance is previous balance + tx amount
         */
        
        XCTAssertEqual(receivedTxTotalBalance, initialTotalBalance + Int64(receivedTx.value))
        XCTAssertEqual(receivedTxVerifiedBalance, initialVerifiedBalance)
        /*
         4. get that transaction hex encoded data
         */
        
        guard let receivedTxData = receivedTx.raw else {
            XCTFail("received tx has no raw data!")
            return
        }
        
        let receivedRawTx = RawTransaction.with { rawTx in
            rawTx.height = UInt64(receivedTxHeight)
            rawTx.data = receivedTxData
        }
        
        /*
         5. stage 5 empty blocks w/heights received_Tx_height to received_Tx_height + 4
         */
        
        try coordinator.stageBlockCreate(height: receivedTxHeight, count: 5)
        
        /*
         6. stage tx at received_Tx_height + 3
         */
        
        let reorgedTxheight = receivedTxHeight + 2
        try coordinator.stageTransaction(receivedRawTx, at:reorgedTxheight)
        
        /*
         6a. applyheight(received_Tx_height + 1)
         */
        
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)
        /*
         7. sync to received_Tx_height + 1
         */
        
        let reorgSyncexpectation = XCTestExpectation(description: "reorg expectation")
        
        var afterReorgTxTotalBalance = Int64(-1)
        var afterReorgTxVerifiedBalance = Int64(-1)
        
        try coordinator.sync(completion: { (synchronizer) in
            afterReorgTxTotalBalance = synchronizer.initializer.getBalance()
            afterReorgTxVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            reorgSyncexpectation.fulfill()
        }, error: self.handleError(_:))
        
        /*
         8. assert that reorg happened at received_Tx_height
         */
        sleep(2)
        wait(for: [reorgExpectation, reorgSyncexpectation], timeout: 5, enforceOrder: false)
        /*
         9. verify that balance equals initial balance
         */
        
        XCTAssertEqual(afterReorgTxVerifiedBalance, initialVerifiedBalance)
        XCTAssertEqual(afterReorgTxTotalBalance, initialTotalBalance)
        
        /*
         10. sync up to received_Tx_height + 3
         */
        
        let finalsyncExpectation = XCTestExpectation(description: "final sync")
        
        var finalReorgTxTotalBalance = Int64(-1)
        var finalReorgTxVerifiedBalance = Int64(-1)
        
        try coordinator.applyStaged(blockheight: reorgedTxheight + 1)
        sleep(3)
        try coordinator.sync(completion: { (synchronizer) in
            finalReorgTxTotalBalance = synchronizer.initializer.getBalance()
            finalReorgTxVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            finalsyncExpectation.fulfill()
        }, error: self.handleError(_:))
        
        wait(for: [finalsyncExpectation], timeout: 5)
        sleep(3)
        
        guard let reorgedTx = coordinator.synchronizer.receivedTransactions.first else {
            XCTFail("no transactions found")
            return
        }
        
        XCTAssertEqual(reorgedTx.minedHeight, reorgedTxheight)
        XCTAssertEqual(initialVerifiedBalance, finalReorgTxVerifiedBalance)
        XCTAssertEqual(initialTotalBalance + Int64(receivedTx.value), finalReorgTxTotalBalance)
    }
    
    /**
     An outbound, unconfirmed transaction in a specific block changes height in the event of a reorg
     
     
     The wallet handles this change, reflects it appropriately in local storage, and funds remain spendable post confirmation.
     
     Pre-conditions:
     - Wallet has spendable funds
     
     1. Setup w/ default dataset
     2. applyStaged(received_Tx_height)
     3. sync up to received_Tx_height
     4. create transaction
     5. stage 10 empty blocks
     6. submit tx at sentTxHeight
     6a. getIncomingTx
     6b. stageTransaction(sentTx, sentTxHeight)
     6c. applyheight(sentTxHeight + 1 )
     7. sync to  sentTxHeight + 2
     8. stage sentTx and otherTx at sentTxheight
     9. applyStaged(sentTx + 2)
     10. sync up to received_Tx_height + 2
     11. verify that the sent tx is mined and balance is correct
     12. applyStaged(sentTx + 10)
     13. verify that there's no more pending transaction
     */
    func testReorgChangesOutboundTxIndex() throws {
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service)
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        
        /*
         2. applyStaged(received_Tx_height)
         */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        /*
         3. sync up to received_Tx_height
         */
        try coordinator.sync(completion: { (synchronizer) in
            initialVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            initialTotalBalance = synchronizer.initializer.getBalance()
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [preTxExpectation], timeout: 5)
        
        let sendExpectation = XCTestExpectation(description: "sendToAddress")
        var p: PendingTransactionEntity?
        var error: Error? = nil
        let sendAmount: Int64 = 10000
        /*
         4. create transaction
         */
        coordinator.synchronizer.sendToAddress(spendingKey: coordinator.spendingKeys!.first!, zatoshi: sendAmount, toAddress: testRecipientAddress, memo: "test transaction", from: 0) { (result) in
            switch result {
            case .success(let pending):
                p = pending
            case .failure(let e):
                error = e
            }
            sendExpectation.fulfill()
        }
        wait(for: [sendExpectation], timeout: 12)
        
        guard let pendingTx = p else {
            XCTFail("error sending to address. Error: \(String(describing: error))")
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
        
        /*
         7. sync to  sentTxHeight + 1
         */
        
        let sentTxSyncExpectation = XCTestExpectation(description: "sent tx sync expectation")
        
        try coordinator.sync(completion: { (s) in
            
            let pMinedHeight = s.pendingTransactions.first?.minedHeight
            XCTAssertEqual(pMinedHeight, sentTxHeight)
            
            sentTxSyncExpectation.fulfill()
        }, error: self.handleError)
        
        
        wait(for: [sentTxSyncExpectation], timeout: 5)
        
        
        /*
         8. stage sentTx and otherTx at sentTxheight
         */
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 20, nonce: 5)
        try coordinator.stageTransaction(url: FakeChainBuilder.someOtherTxUrl, at: sentTxHeight)
        try coordinator.stageTransaction(sentTx, at: sentTxHeight)
        
        /*
         9. applyStaged(sentTx + 1)
         */
        try coordinator.applyStaged(blockheight: sentTxHeight + 1)
        
        sleep(2)
        let afterReOrgExpectation = XCTestExpectation(description: "after ReOrg Expectation")
        try coordinator.sync(completion: { (s) in
            /*
             11. verify that the sent tx is mined and balance is correct
             */
            let pMinedHeight = s.pendingTransactions.first?.minedHeight
            XCTAssertEqual(pMinedHeight, sentTxHeight)
            XCTAssertEqual(initialTotalBalance - sendAmount - Int64(1000), s.initializer.getBalance()) // fee change on this branch
            afterReOrgExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [afterReOrgExpectation], timeout: 5)
        
        
        /*
         12. applyStaged(sentTx + 10)
         */
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 12)
        sleep(2)
        /*
         13. verify that there's no more pending transaction
         */
        let lastSyncExpectation = XCTestExpectation(description: "sync to confirmation")
        
        try coordinator.sync(completion: { (s) in
            
            lastSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [lastSyncExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.pendingTransactions.count, 0)
        XCTAssertEqual(initialTotalBalance - Int64(pendingTx.value) - Int64(1000), coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), coordinator.synchronizer.initializer.getVerifiedBalance())
    }
    
    func testIncomingTransactionIndexChange() throws {
        hookToReOrgNotification()
        self.expectedReorgHeight = 663196
        self.expectedRewindHeight = 663175
        try coordinator.reset(saplingActivation: birthday)
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeBefore))
        try coordinator.applyStaged(blockheight: 663195)
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        var preReorgTotalBalance = Int64(0)
        var preReorgVerifiedBalance = Int64(0)
        try coordinator.sync(completion: { (synchronizer) in
            preReorgTotalBalance = synchronizer.initializer.getBalance()
            preReorgVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        
        /*
         trigger reorg
         */
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeAfter))
        try coordinator.applyStaged(blockheight: 663200)
        
        sleep(1)
        
        let afterReorgSync = XCTestExpectation(description: "after reorg sync")
        
        var postReorgTotalBalance = Int64(0)
        var postReorgVerifiedBalance = Int64(0)
        try coordinator.sync(completion: { (synchronizer) in
            postReorgTotalBalance = synchronizer.initializer.getBalance()
            postReorgVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            afterReorgSync.fulfill()
        }, error: self.handleError)
        
        wait(for: [reorgExpectation,afterReorgSync], timeout: 5)
        
        XCTAssertEqual(postReorgVerifiedBalance, preReorgVerifiedBalance)
        XCTAssertEqual(postReorgTotalBalance, preReorgTotalBalance)
        
    }
    
    func testReOrgExpiresInboundTransaction() throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        let receivedTxHeight = BlockHeight(663188)
        try coordinator.applyStaged(blockheight: receivedTxHeight - 1)
        sleep(2)
        let expectation = XCTestExpectation(description: "sync to \(receivedTxHeight - 1) expectation")
        var initialBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        try coordinator.sync(completion: { (synchronizer) in
            initialBalance = synchronizer.initializer.getBalance()
            initialVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            expectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [expectation], timeout: 5)
        
        let afterTxHeight = receivedTxHeight + 1
        try coordinator.applyStaged(blockheight: afterTxHeight)
        sleep(2)
        let afterTxSyncExpectation = XCTestExpectation(description: "sync to \(afterTxHeight) expectation")
        
        var afterTxBalance: Int64 = -1
        var afterTxVerifiedBalance: Int64 = -1
        try coordinator.sync(completion: { (synchronizer) in
            afterTxBalance = synchronizer.initializer.getBalance()
            afterTxVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            XCTAssertNotNil(synchronizer.receivedTransactions.first { $0.minedHeight == receivedTxHeight }, "Transaction not found at \(receivedTxHeight)")
            afterTxSyncExpectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [afterTxSyncExpectation], timeout: 10.0)
        
        XCTAssertEqual(initialVerifiedBalance, afterTxVerifiedBalance)
        XCTAssertNotEqual(initialBalance, afterTxBalance)
        
        let reorgSize: Int = 3
        let newBlocksCount: Int = 11 + reorgSize
        try coordinator.stageBlockCreate(height: receivedTxHeight - reorgSize, count: newBlocksCount + reorgSize)
        try coordinator.applyStaged(blockheight: receivedTxHeight + newBlocksCount - 1)
        
        sleep(2)
        let afterReorgExpectation = XCTestExpectation(description: "after reorg expectation")
        
        var afterReOrgBalance: Int64 = -1
        var afterReOrgVerifiedBalance: Int64 = -1
        try coordinator.sync(completion: { (synchronizer) in
            afterReOrgBalance = synchronizer.initializer.getBalance()
            afterReOrgVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            XCTAssertNil(synchronizer.receivedTransactions.first { $0.minedHeight == receivedTxHeight }, "Transaction found at \(receivedTxHeight) after reorg")
            afterReorgExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [afterReorgExpectation], timeout: 5)
        
        XCTAssertEqual(afterReOrgBalance, initialBalance)
        XCTAssertEqual(afterReOrgVerifiedBalance, initialVerifiedBalance)
        
    }
    
    /**
     Steps:
     1.  sync up to an incoming transaction (incomingTxHeight + 1)
     1a. save balances
     2. stage 4 blocks from incomingTxHeight - 1 with different nonce
     3. stage otherTx at incomingTxHeight
     4. stage incomingTx at incomingTxHeight
     5. applyHeight(incomingHeight + 3)
     6. sync to latest height
     7. check that balances still match
     */
    func testReOrgChangesInboundTxIndexInBlock() throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        let incomingTxHeight = BlockHeight(663188)
        
        try coordinator.applyStaged(blockheight: incomingTxHeight + 1)
        
        /*
         1.  sync up to an incoming transaction (incomingTxHeight + 1)
         */
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync test expectation")
        
        var initialBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        var incomingTx: ConfirmedTransactionEntity? = nil
        try coordinator.sync(completion: { (synchronizer) in
            
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        /*
         1a. save balances
         */
        initialBalance = coordinator.synchronizer.initializer.getBalance()
        initialVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        incomingTx = coordinator.synchronizer.receivedTransactions.first(where: { $0.minedHeight == incomingTxHeight })
        guard let tx = incomingTx else {
            XCTFail("no tx found")
            return
        }
        
        guard let txRawData = tx.raw else {
            XCTFail("transaction has no raw data")
            return
        }
        
        let rawTransaction = RawTransaction.with( { tx in
            tx.data = txRawData
        })
        
        /*
         2. stage 4 blocks from incomingTxHeight - 1 with different nonce
         */
        let blockCount = 4
        try coordinator.stageBlockCreate(height: incomingTxHeight - 1, count: blockCount, nonce: Int.random(in: 0 ... Int.max))
        
        /*
         3. stage otherTx at incomingTxHeight
         */
        
        try coordinator.stageTransaction(url: FakeChainBuilder.someOtherTxUrl, at: incomingTxHeight)
        
        /*
         4. stage incomingTx at incomingTxHeight
         5. applyHeight(incomingHeight + 3)
         6. sync to latest height
         7. check that balances still match
         */
        try coordinator.stageTransaction(rawTransaction, at: incomingTxHeight)
        
        /*
         5. applyHeight(incomingHeight + 2)
         */
        
        try coordinator.applyStaged(blockheight: incomingTxHeight + 2)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")
        /*
         6. sync to latest height
         */
        try coordinator.sync(completion: { (s) in
            lastSyncExpectation.fulfill()
        }, error: self.handleError)
        
        /*
         7. check that balances still match
         */
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), initialVerifiedBalance)
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), initialBalance)
        
        wait(for: [lastSyncExpectation], timeout: 5)
    }
    
    func testTxIndexReorg() throws {
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeBefore))
        
        let txReorgHeight = BlockHeight(663195)
        let finalHeight = BlockHeight(663200)
        try coordinator.applyStaged(blockheight: txReorgHeight)
        let firstSyncExpectation = XCTestExpectation(description: "first sync test expectation")
        var initialBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        try coordinator.sync(completion: { (synchronizer) in
            
            initialBalance = synchronizer.initializer.getBalance()
            initialVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        try coordinator.resetBlocks(dataset:.predefined(dataset: .txIndexChangeAfter))
        
        try coordinator.applyStaged(blockheight: finalHeight)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")
        
        try coordinator.sync(completion: { (s) in
            lastSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [lastSyncExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), initialBalance)
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), initialVerifiedBalance)
    }
    
    /**
     A Re Org occurs and changes the height of an outbound transaction
     Pre-condition: Wallet has funds
     
     Steps:
     1. create fake chain
     1a. sync to latest height
     2. send transaction to recipient address
     3. getIncomingTransaction
     4. stage transaction at sentTxHeight
     5. applyHeight(sentTxHeight)
     6. sync to latest height
     6a. verify that there's a pending transaction with a mined height of sentTxHeight
     7. stage 15  blocks from sentTxHeight
     7. a stage sent tx to sentTxHeight + 2
     8. applyHeight(sentTxHeight + 1) to cause a 1 block reorg
     9. sync to latest height
     10. verify that there's a pending transaction with -1 mined height
     11. applyHeight(sentTxHeight + 2)
     11a. sync to latest height
     12. verify that there's a pending transaction with a mined height of sentTxHeight + 2
     13. apply height(sentTxHeight + 15)
     14. sync to latest height
     15. verify that there's no pending transaction and that the tx is displayed on the sentTransactions collection
     
     */
    func testReOrgChangesOutboundTxMinedHeight() throws {
        hookToReOrgNotification()
        /*
         1. create fake chain
         */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: 663188)
        sleep(2)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
         1a. sync to latest height
         */
        try coordinator.sync(completion: { (s) in
            
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        sleep(1)
        let initialTotalBalance = coordinator.synchronizer.initializer.getBalance()
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var p: PendingTransactionEntity? = nil
        
        /*
         2. send transaction to recipient address
         */
        coordinator.synchronizer.sendToAddress(spendingKey: self.coordinator.spendingKeys!.first!, zatoshi: 20000, toAddress: self.testRecipientAddress, memo: "this is a test", from: 0, resultBlock: { (result) in
            switch result {
            case .failure(let e):
                self.handleError(e)
            case .success(let pendingTx):
                p = pendingTx
            }
            sendExpectation.fulfill()
        })
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard let _ = p else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        /**
         3. getIncomingTransaction
         */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
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
        let secondSyncExpectation =  XCTestExpectation(description: "after send expectation")
        
        try coordinator.sync(completion: { (s) in
            secondSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [secondSyncExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.pendingTransactions.count, 1)
        guard let afterStagePendingTx = coordinator.synchronizer.pendingTransactions.first else {
            return
        }
        
        /*
         6a. verify that there's a pending transaction with a mined height of sentTxHeight
         */
        
        XCTAssertEqual(afterStagePendingTx.minedHeight, sentTxHeight)
        
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
        
        try coordinator.sync(completion: { (s) in
            afterReorgExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [reorgExpectation,afterReorgExpectation], timeout: 5)
        
        /*
         10. verify that there's a pending transaction with -1 mined height
         */
        guard let newPendingTx = coordinator.synchronizer.pendingTransactions.first else {
            XCTFail("No pending transaction")
            try coordinator.stop()
            return
        }
        
        XCTAssertEqual(newPendingTx.minedHeight, BlockHeight.empty())
        
        /*
         11. applyHeight(sentTxHeight + 2)
         */
        try coordinator.applyStaged(blockheight: sentTxHeight + 2)
        sleep(2)
        
        
        let yetAnotherExpectation = XCTestExpectation(description: "after staging expectation")
        
        /*
         11a. sync to latest height
         */
        try coordinator.sync(completion: { (s) in
            yetAnotherExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [yetAnotherExpectation], timeout: 5)
        
        
        /*
         12. verify that there's a pending transaction with a mined height of sentTxHeight + 2
         */
        
        XCTAssertEqual(coordinator.synchronizer.pendingTransactions.count,1)
        guard let newlyPendingTx = try coordinator.synchronizer.allPendingTransactions().first else {
            XCTFail("no pending transaction")
            try coordinator.stop()
            return
        }
        
        XCTAssertEqual(newlyPendingTx.minedHeight, sentTxHeight + 2)
        
        /*
         13. apply height(sentTxHeight + 25)
         */
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 25)
        
        sleep(2)
        
        let thisIsTheLastExpectationIPromess = XCTestExpectation(description: "last sync")
        /*
         14. sync to latest height
         */
        
        try coordinator.sync(completion: { (s) in
            thisIsTheLastExpectationIPromess.fulfill()
        }, error: self.handleError)
        
        wait(for: [thisIsTheLastExpectationIPromess], timeout: 5)
        
        /*
         15. verify that there's no pending transaction and that the tx is displayed on the sentTransactions collection
         */
        
        XCTAssertEqual(coordinator.synchronizer.pendingTransactions.count, 0)
        XCTAssertNotNil(coordinator.synchronizer.sentTransactions.first(where: { t in
            guard let txId = t.rawTransactionId else { return false }
            return txId == newlyPendingTx.rawTransactionId
        }), "Sent Tx is not on sent transactions")
        
        XCTAssertEqual(initialTotalBalance - Int64(newlyPendingTx.value) - Int64(1000), coordinator.synchronizer.initializer.getBalance())
        XCTAssertEqual(initialTotalBalance - Int64(newlyPendingTx.value) - Int64(1000),  coordinator.synchronizer.initializer.getVerifiedBalance())
        
        
    }
    /**
     Uses the zcash-hackworks data set.
     
     A Re Org occurs at 663195, and sweeps an Inbound Tx that appears later on the chain.
     Steps:
     1. reset dlwd
     2. load blocks from txHeightReOrgBefore
     3. applyStaged(663195)
     4. sync to latest height
     5. get balances
     6. load blocks from dataset txHeightReOrgBefore
     7. apply stage 663200
     8. sync to latest height
     9. verify that the balance is equal to the one before the reorg
     */
    func testReOrgChangesInboundMinedHeight() throws {
        try coordinator.reset(saplingActivation: 663150)
        sleep(2)
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txHeightReOrgBefore))
        sleep(2)
        try coordinator.applyStaged(blockheight: 663195)
        sleep(2)
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.sync(completion: { (s) in
            
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        let initialBalance = coordinator.synchronizer.initializer.getBalance()
        let initialVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        guard let initialTxHeight = try coordinator.synchronizer.allReceivedTransactions().first?.minedHeight else {
            XCTFail("no incoming transaction found!")
            return
        }
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txHeightReOrgAfter))
        
        sleep(5)
        
        try coordinator.applyStaged(blockheight: 663200)
        
        sleep(6)
        
        let afterReOrgExpectation = XCTestExpectation(description: "after reorg")
        try coordinator.sync(completion: { (s) in
            
            afterReOrgExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [afterReOrgExpectation], timeout: 5)
        
        guard let afterReOrgTxHeight = coordinator.synchronizer.receivedTransactions.first?.minedHeight else {
            XCTFail("no incoming transaction found after re org!")
            return
        }
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(initialBalance, coordinator.synchronizer.initializer.getBalance())
        XCTAssert(afterReOrgTxHeight > initialTxHeight)
        
    }
    /**
     Re Org removes incoming transaction and is never mined
     Steps:
     1. sync prior to incomingTxHeight - 1 to get balances there
     2. sync to latest height
     3. cause reorg
     4. sync to latest height
     5. verify that reorg Happened at reorgHeight
     6. verify that balances match initial balances
     */
    func testReOrgRemovesIncomingTxForever() throws {
        hookToReOrgNotification()
        try coordinator.reset(saplingActivation: 663150)
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txReOrgRemovesInboundTxBefore))
        
        let reorgHeight: BlockHeight = 663195
        self.expectedReorgHeight = reorgHeight
        self.expectedRewindHeight = reorgHeight - 10
        
        try coordinator.applyStaged(blockheight: reorgHeight - 1)
        
        sleep(2)
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.sync(completion: { (s) in
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        let initialTotalBalance = coordinator.synchronizer.initializer.getBalance()
        let initialVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        
        try coordinator.applyStaged(blockheight: reorgHeight)
        
        let secondSyncExpectation = XCTestExpectation(description: "second sync expectation")
        
        try coordinator.sync(completion: { (s) in
            secondSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [secondSyncExpectation], timeout: 5)
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txReOrgRemovesInboundTxAfter))
        
        try coordinator.applyStaged(blockheight: 663200)
        sleep(2)
        
        let afterReorgSyncExpectation = XCTestExpectation(description: "after reorg expectation")
        try coordinator.sync(completion: { (s) in
            afterReorgSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [afterReorgSyncExpectation], timeout: 5)
        
        XCTAssertEqual(initialVerifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(initialTotalBalance, coordinator.synchronizer.initializer.getBalance())
    }
    
    /**
     Transaction was included in a block, and then is not included in a block after a reorg, and expires.
     Steps:
     1. create fake chain
     1a. sync to latest height
     2. send transaction to recipient address
     3. getIncomingTransaction
     4. stage transaction at sentTxHeight
     5. applyHeight(sentTxHeight)
     6. sync to latest height
     6a. verify that there's a pending transaction with a mined height of sentTxHeight
     7. stage 15 blocks from sentTxHeigth to cause a reorg
     8. sync to latest height
     9. verify that there's an expired transaction as a pending transaction
     */
    func testReOrgRemovesOutboundTxAndIsNeverMined() throws {
        hookToReOrgNotification()
        
        /*
         1. create fake chain
         */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        let sentTxHeight: BlockHeight = 663195
        try coordinator.applyStaged(blockheight: sentTxHeight - 1)
        
        
        sleep(2)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
         1a. sync to latest height
         */
        try coordinator.sync(completion: { (s) in
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        sleep(1)
        let initialTotalBalance = coordinator.synchronizer.initializer.getBalance()
        
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var p: PendingTransactionEntity? = nil
        
        /*
         2. send transaction to recipient address
         */
        coordinator.synchronizer.sendToAddress(spendingKey: self.coordinator.spendingKeys!.first!, zatoshi: 20000, toAddress: self.testRecipientAddress, memo: "this is a test", from: 0, resultBlock: { (result) in
            switch result {
            case .failure(let e):
                self.handleError(e)
            case .success(let pendingTx):
                p = pendingTx
            }
            sendExpectation.fulfill()
        })
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard let _ = p else {
            XCTFail("no pending transaction after sending")
            try coordinator.stop()
            return
        }
        /**
         3. getIncomingTransaction
         */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try coordinator.stop()
            return
        }
        
        self.expectedReorgHeight = sentTxHeight + 1
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
        let secondSyncExpectation =  XCTestExpectation(description: "after send expectation")
        
        try coordinator.sync(completion: { (s) in
            secondSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [secondSyncExpectation], timeout: 5)
        let extraBlocks = 25
        try coordinator.stageBlockCreate(height: sentTxHeight, count: extraBlocks, nonce: 5)
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 5)
        
        sleep(2)
        let reorgSyncExpectation = XCTestExpectation(description: "reorg sync expectation")
        
        try coordinator.sync(completion: { (s) in
            reorgSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [reorgExpectation, reorgSyncExpectation], timeout: 5)
        
        guard let pendingTx = coordinator.synchronizer.pendingTransactions.first else {
            XCTFail("no pending transaction after reorg sync")
            return
        }
        
        XCTAssertFalse(pendingTx.isMined)
        
        LoggerProxy.info("applyStaged(blockheight: \(sentTxHeight + extraBlocks - 1))")
        try coordinator.applyStaged(blockheight: sentTxHeight + extraBlocks - 1)
        
        sleep(2)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")
        
        try coordinator.sync(completion: { (s) in
            lastSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [lastSyncExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), initialTotalBalance)
        
    }
    
    func testLongSync() throws {
        
        hookToReOrgNotification()
        
        /*
         1. create fake chain
         */
        let fullSyncLength = 100_000
    
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, length: fullSyncLength)
        
        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)
        
        sleep(10)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
         sync to latest height
         */
        try coordinator.sync(completion: { (s) in
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 300)
        
        XCTAssertEqual(try coordinator.synchronizer.latestDownloadedHeight(), birthday + fullSyncLength)
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
