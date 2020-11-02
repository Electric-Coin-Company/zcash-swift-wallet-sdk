//
//  NetworkUpgradeTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 10/30/20.
//

import XCTest
@testable import ZcashLightClientKit
class NetworkUpgradeTests: XCTestCase {
    
    let activationHeight: BlockHeight = 1_046_400
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" //TODO: Parameterize this from environment?
    
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a" //TODO: Parameterize this from environment
    
    let sendAmount: Int64 = 1000
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
   
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


    /**
     Given that a wallet had funds prior to activation it can spend them after activation
     */
    func testSpendPriorFundsAfterActivation() throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, networkActivationHeight: activationHeight, length: 100)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight - ZcashSDK.EXPIRY_OFFSET)
        sleep(3)
        
        try coordinator.sync(completion: { (synchronizer) in
          
            firstSyncExpectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 10)
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        XCTAssertTrue(verifiedBalance > ZcashSDK.MINERS_FEE_ZATOSHI)
        
        
        try coordinator.applyStaged(blockheight: activationHeight + 1)
        sleep(2)
        
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var p: PendingTransactionEntity? = nil
        let spendAmount: Int64 = 10000
        /*
         send transaction to recipient address
         */
        coordinator.synchronizer.sendToAddress(spendingKey: self.coordinator.spendingKeys!.first!, zatoshi: spendAmount, toAddress: self.testRecipientAddress, memo: "this is a test", from: 0, resultBlock: { (result) in
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
        
        try coordinator.applyStaged(blockheight: activationHeight + 1 + 10)
        
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try coordinator.sync(completion: { (synchronizer) in
          
            afterSendExpectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [afterSendExpectation], timeout: 10)
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), verifiedBalance - Int64(ZcashSDK.MINERS_FEE_ZATOSHI) - spendAmount)
        
    }
    
    /**
     Given that a wallet receives funds after activation it can spend them when confirmed
     */
    func testSpendPostActivationFundsAfterConfirmation() throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, networkActivationHeight: activationHeight, length: 100)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try coordinator.applyStaged(blockheight: activationHeight + 10)
        sleep(3)
        
        try coordinator.sync(completion: { (synchronizer) in
          
            firstSyncExpectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [firstSyncExpectation], timeout: 10)
        guard try coordinator.synchronizer.allReceivedTransactions().filter({$0.minedHeight > activationHeight}).count > 0 else {
            XCTFail("this test requires funds received after activation height")
            return
        }
        
        try coordinator.applyStaged(blockheight: activationHeight + 20)
        sleep(2)
        
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var p: PendingTransactionEntity? = nil
        let spendAmount: Int64 = 10000
        /*
         send transaction to recipient address
         */
        coordinator.synchronizer.sendToAddress(spendingKey: self.coordinator.spendingKeys!.first!, zatoshi: spendAmount, toAddress: self.testRecipientAddress, memo: "this is a test", from: 0, resultBlock: { (result) in
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
        
        try coordinator.applyStaged(blockheight: activationHeight + 1 + 10)
        
        let afterSendExpectation = XCTestExpectation(description: "aftersend")
        
        try coordinator.sync(completion: { (synchronizer) in
          
            afterSendExpectation.fulfill()
            
        }, error: self.handleError)
        
        wait(for: [afterSendExpectation], timeout: 10)
        
    }
    /**
     Given that a wallet sends funds some between (activation - expiry_height) and activation, those funds are shown as sent if mined.

     */
    func testSpendMinedSpendThatExpiresOnActivation() throws {
        XCTFail()
    }
    
    /**
     Given that a wallet sends funds some between (activation - expiry_height) and activation, those funds are available if  expired after expiration height.
     */
    
    func testExpiredSpendAfterActivation() throws {
        XCTFail()
    }
    
    /**
     Given that a wallet has notes both received prior and after activation these can be combined to supply a larger amount spend.
     */
    func testCombinePreActivationNotesAndPostActivationNotesOnSpend() throws {
        XCTFail()
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
