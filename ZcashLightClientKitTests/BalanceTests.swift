//
//  BalanceTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/28/20.
//

import XCTest
@testable import ZcashLightClientKit
class BalanceTests: XCTestCase {
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" //TODO: Parameterize this from environment?
    
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a" //TODO: Parameterize this from environment
    
    let sendAmount = 1000
    var birthday: BlockHeight = 663174
    var coordinator: TestCoordinator!
    
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    override func setUpWithError() throws {
        
        coordinator = TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /**
     
     Verify available balance is correct in all wallet states during a send
     
     This can be either a Wallet test or a Synchronizer test. The latter is supposed to be simpler because it involves no UI testing whatsoever.
     
     Precondition:
     Account has spendable funds
     Librustzcash is ‘synced’ up to ‘current tip’
     
     Action:
     Send Amount(*) to zAddr
     
     Success per state:
     Sent:  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
     Error:  previous available funds  equals to current funds

     */
    func testVerifyAvailableBalanceDuringSend() throws {
        var syncedSynchronizer: SDKSynchronizer?
        
        try coordinator.sync(to: .latestHeight, completion: { (synchronizer) in
            syncedSynchronizer = syncedSynchronizer
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let synchronizer = syncedSynchronizer, let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create synchronizer")
            return
        }
        
        let presendBalance = synchronizer.initializer.getVerifiedBalance()
        XCTAssertTrue(presendBalance >= (ZcashSDK.MINERS_FEE_ZATOSHI + sendAmount))  // there's more zatoshi to send than network fee
        
        
        synchronizer.sendToAddress(spendingKey: spendingKey,
                                   zatoshi: Int64(sendAmount),
                                   toAddress: testRecipientAddress,
                                   memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let error):
                // balance should be the same as before sending if transaction failed
                XCTAssertEqual(synchronizer.initializer.getVerifiedBalance(), presendBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let transaction):
                XCTAssertEqual(transaction.value, self.sendAmount)
               
                guard let txid = transaction.id else {
                    XCTFail("sent transaction has no internal id")
                    return
                }
                let sentNoteDAO = SentNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
                
                let receivedNoteDAO = ReceivedNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
                
                guard let sentNote =  sentNoteDAO.sentNote(byTransactionId: txid) else {
                    XCTFail("could not find sent note for this transaction")
                    return
                }
                
                guard let receivedNote = receivedNoteDAO.receivedNote(byTransactionId: txid) else {
                    XCTFail("could not find sent note for this transaction")
                    return
                }
                 //  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
                XCTAssertEqual(presendBalance - Int64(sentNote.value) + Int64(receivedNote.value), synchronizer.initializer.getVerifiedBalance() - Int64(self.sendAmount))
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
    }
    
    /**
     Verify total balance in all wallet states during a send
     This can be either a Wallet test or a Synchronizer test. The latter is supposed to be simpler because it involves no UI testing whatsoever.
     
     Precondition:
     Account has spendable funds
     Librustzcash is ‘synced’ up to ‘current tip’
     
     Action:
     Send Amount to zAddr
     
     Success per state:
     Sent:  (total balance funds - sentAmount) equals to (previous available funds - sent amount)
     Error:  previous total balance  funds  equals to current total balance
     
     */
    func testVerifyTotalBalanceDuringSend() throws {
        var syncedSynchronizer: SDKSynchronizer?
        
        try coordinator.sync(to: .latestHeight, completion: { (synchronizer) in
            syncedSynchronizer = syncedSynchronizer
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let synchronizer = syncedSynchronizer, let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create synchronizer")
            return
        }
        
        let presendBalance = synchronizer.initializer.getVerifiedBalance()
        XCTAssertTrue(presendBalance >= (ZcashSDK.MINERS_FEE_ZATOSHI + sendAmount))  // there's more zatoshi to send than network fee
        
        
        synchronizer.sendToAddress(spendingKey: spendingKey,
                                   zatoshi: Int64(sendAmount),
                                   toAddress: testRecipientAddress,
                                   memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let error):
                // balance should be the same as before sending if transaction failed
                XCTAssertEqual(synchronizer.initializer.getVerifiedBalance(), presendBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let transaction):
                XCTAssertEqual(transaction.value, self.sendAmount)
                XCTAssertEqual(synchronizer.initializer.getBalance(), presendBalance - Int64(self.sendAmount))
                XCTAssertNil(transaction.errorCode)
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
    }
    
    /**
     Verify incoming transactions
     This can be either a Wallet test or a Synchronizer test. The latter is supposed to be simpler because it involves no UI testing whatsoever.
     
     Precondition:
     Librustzcash is ‘synced’ up to ‘current tip’
     Known list of expected transactions on the block range to sync the wallet up to.
     Known expected balance on the block range to sync the wallet up to.
     Action:
     sync to latest height
     Success criteria:
     The transaction list matches the expected one
     Balance matches expected balance
     
     */
    func testVerifyIncomingTransaction() throws {
        
        try coordinator.sync(to: .upTo(height: 663230), completion: { (syncronizer) in
            XCTAssertEqual(syncronizer.clearedTransactions.count, 5)
            XCTAssertEqual(syncronizer.initializer.getBalance(), 410000)
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 60) // ten minutes
    }
    
    func testVerifyChangeTransaction() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTFail("not yet implemented")
    }
    
    
    func testVerifyBalanceAfterExpiredTransaction() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTFail("not yet implemented")
    }
    
    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
