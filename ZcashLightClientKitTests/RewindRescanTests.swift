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
        
        // rewind to birthday
        try coordinator.synchronizer.rewind(.birthday)
        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.latestHeight(), birthday)
        
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
        
        // rewind to birthday
        let targetRewind = BlockHeight(663160)
        try coordinator.synchronizer.rewind(.height(blockheight: targetRewind))
        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.latestHeight(), targetRewind)
        
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
        // 2 check that there are no unconfirmed funds
        
        let verifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let totalBalance = coordinator.synchronizer.initializer.getBalance()
        XCTAssertTrue(verifiedBalance > ZcashSDK.defaultFee())
        XCTAssertEqual(verifiedBalance, totalBalance)
        
        // rewind to transaction
        
        
        guard let transaction = try coordinator.synchronizer.allClearedTransactions().first else {
            XCTFail("failed to get a transaction to rewind to")
            return
        }
        
        try coordinator.synchronizer.rewind(.transaction(transaction.transactionEntity))
        
        // assert that after the new height is
        XCTAssertEqual(try coordinator.latestHeight(), transaction.minedHeight)
        
        let secondScanExpectation = XCTestExpectation(description: "rescan")
        
        try coordinator.sync(completion: { (synchronizer) in
            secondScanExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [secondScanExpectation], timeout: 12)
        
        // verify that the balance still adds up
        
        XCTAssertEqual(verifiedBalance, coordinator.synchronizer.initializer.getVerifiedBalance())
        XCTAssertEqual(totalBalance, coordinator.synchronizer.initializer.getBalance())
        
    }


}
