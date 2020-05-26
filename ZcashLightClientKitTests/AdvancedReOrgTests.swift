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
            serviceType: .darksideLightwallet(threshold: .upTo(height: defaultLatestHeight),dataset: .default),
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
        try coordinator.reset(saplingActivation: 663150)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
    @objc func handleReorg(_ notification: Notification) {
        
        guard let reorgHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight else {
                XCTFail("empty reorg notification")
                return
        }
        
        XCTAssertEqual(rewindHeight, expectedRewindHeight)
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service as! DarksideWalletService)
        var shouldContinue =  false
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        
        /*
         precondition:know balances before tx at received_Tx_height arrives
         */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
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
//        sleep(1)
        
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
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [receivedTxExpectation], timeout: 5)
        
        guard let syncedSynchronizer = s else {
            XCTFail("nil synchronizer")
            return
        }
        
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
        
        let receivedRawTx = try RawTransaction(serializedData: receivedTxData)
        
        /*
         5. stage 5 empty blocks w/heights received_Tx_height to received_Tx_height + 3
         */
        
        try coordinator.stageBlockCreate(height: receivedTxHeight, count: 3)
        
        /*
         6. stage tx at received_Tx_height + 3
         */
        
        let reorgedTxheight = receivedTxHeight + 3
        try coordinator.stageTransaction(receivedRawTx, at:reorgedTxheight)
        
        /*
         6a. applyheight(received_Tx_height + 1)
         */
        
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
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
        wait(for: [reorgExpectation, reorgSyncexpectation], timeout: 5, enforceOrder: true)
        
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
        
        try coordinator.applyStaged(blockheight: reorgedTxheight)
        
        try coordinator.sync(completion: { (synchronizer) in
            finalReorgTxTotalBalance = synchronizer.initializer.getBalance()
            finalReorgTxVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            finalsyncExpectation.fulfill()
        }, error: self.handleError(_:))
        
        XCTAssertEqual(initialVerifiedBalance, finalReorgTxVerifiedBalance)
        XCTAssertEqual(initialTotalBalance + Int64(receivedTx.value), finalReorgTxTotalBalance  )
    }
    
    /**
     An outbound, unconfirmed transaction in a specific block changes index in the event of a reorg without a block height change.
     
     Conditions:
     1) Height remains the same
     2) prevhash remains the same
     3) Index changes
     
     The wallet handles this change, reflects it appropriately in local storage, and funds remain spendable post confirmation.
     
     Pre-conditions:
     - There's a known transaction that's involved with this wallet
     - There's another transaction that's not for this wallet
     
     1. Setup w/ default dataset
     2. applyStaged(received_Tx_height)
     3. sync up to received_Tx_height
     3a. verify that balance is previous balance + tx amount
     4. get that transaction hex encoded data
     5. stage 10 empty blocks w/heights received_Tx_height to received_Tx_height
     6. stage tx at received_Tx_height
        6a. stage tx at received_Tx_height
        6b. applyheight(received_Tx_height )
     7. sync to received_Tx_height + 1
     8. assert that reorg happened at received_Tx_height
     9. verify that balance equals initial balance
     10. sync up to received_Tx_height + 10
     11. verify that balance equals initial balance + tx amount
     */
    func testTxIndexChangeReorg() throws {
        try coordinator.reset(saplingActivation: birthday)
        try coordinator.resetBlocks(dataset: .default)
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance: Int64 = -1
        var initialVerifiedBalance: Int64 = -1
        
        /*
         precondition:know balances before tx at received_Tx_height arrives
         */
        try coordinator.applyStaged(blockheight: receivedTxHeight - 1)
        
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        var s: SDKSynchronizer?
        
        try coordinator.sync(completion: { (synchronizer) in
            s = synchronizer
            initialVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            initialTotalBalance = synchronizer.initializer.getBalance()
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [preTxExpectation], timeout: 5)
        /*
         2. applyStaged(received_Tx_height)
         */
        
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
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
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [receivedTxExpectation], timeout: 5)
        
        guard let syncedSynchronizer = s else {
            XCTFail("nil synchronizer")
            return
        }
        
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
        
        let receivedRawTx = try RawTransaction(serializedData: receivedTxData)
        
        /*
         5. stage 5 empty blocks w/heights received_Tx_height to received_Tx_height + 3
         */
        
        try coordinator.stageBlockCreate(height: receivedTxHeight, count: 3)
        
        /*
         6. stage tx at received_Tx_height
         */
        
        let reorgedTxheight = receivedTxHeight
        try coordinator.stageTransaction(receivedRawTx, at:reorgedTxheight)
       
        /*
         6b. applyStaged(received_Tx_height)
         */
        
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
        /*
        7. sync to received_Tx_height
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
       wait(for: [reorgExpectation, reorgSyncexpectation], timeout: 5, enforceOrder: true)
       
       /*
        9. verify that balance equals initial balance
        */
       XCTAssertEqual(afterReorgTxVerifiedBalance, receivedTxVerifiedBalance)
       XCTAssertEqual(afterReorgTxTotalBalance, receivedTxTotalBalance)
        
        /*
         10. Sync to final height and check confirmed funds
         */
        
        let finalSyncExpectation = XCTestExpectation(description: "final transaction")
        var finalTotalBalance = Int64(-1)
        var finalVerifiedBalance = Int64(-1)
        try coordinator.sync(completion: { (synchronizer) in
            finalTotalBalance = synchronizer.initializer.getBalance()
            finalVerifiedBalance = synchronizer.initializer.getVerifiedBalance()
            finalSyncExpectation.fulfill()
        }, error: self.handleError)
        
        XCTAssertEqual(finalTotalBalance, initialTotalBalance + Int64(receivedTx.value))
        XCTAssertEqual(finalVerifiedBalance, finalTotalBalance)
        
    }
    
    func testIncomingTransactionIndexChange() throws {
        try coordinator.reset(saplingActivation: birthday)
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeBefore))
        try coordinator.applyStaged(blockheight: 663200)
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
    
    func testReOrgExpiresInboundTransaction() {
        
    }
    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
    
    
}
