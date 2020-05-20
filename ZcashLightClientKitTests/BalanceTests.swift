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
    
    let sendAmount: Int64 = 1000
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663201
    var coordinator: TestCoordinator!
    
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    override func setUpWithError() throws {
        
        coordinator = try TestCoordinator(
            serviceType: .darksideLightwallet(threshold: .upTo(height: defaultLatestHeight),dataset: .default),
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
        try coordinator.resetBlocks(dataset: .default)
        
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
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        var syncedSynchronizer: SDKSynchronizer?
        
        try coordinator.sync(completion: { (synchronizer) in
            syncedSynchronizer = syncedSynchronizer
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let synchronizer = syncedSynchronizer, let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create synchronizer")
            return
        }
        
        let presendBalance = synchronizer.initializer.getVerifiedBalance()
        
        /*
         there's more zatoshi to send than network fee
         */
        XCTAssertTrue(presendBalance >= (Int64(ZcashSDK.MINERS_FEE_ZATOSHI) + sendAmount))
        
        var pendingTx: PendingTransactionEntity?
        synchronizer.sendToAddress(spendingKey: spendingKey,
                                   zatoshi: Int64(sendAmount),
                                   toAddress: testRecipientAddress,
                                   memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let error):
                /*
                 balance should be the same as before sending if transaction failed
                 */
                XCTAssertEqual(synchronizer.initializer.getVerifiedBalance(), presendBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let transaction):
                
                pendingTx = transaction
                /*
                 basic health check
                 */
                XCTAssertEqual(Int64(transaction.value), self.sendAmount)
                
                /*
                 build up repos to get data
                 */
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
                
                XCTAssertTrue(
                    self.verifiedBalanceValidation(previousBalance: presendBalance,
                                                   spentNoteValue:  Int64(sentNote.value),
                                                   changeValue: Int64(receivedNote.value),
                                                   sentAmount: Int64(self.sendAmount),
                                                   currentVerifiedBalance: synchronizer.initializer.getVerifiedBalance())
                )
                
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
        // sync and mine
        
        guard let tx = pendingTx, let txData = tx.raw else {
            XCTFail("pending transaction nil after send")
            return
        }
        let latestHeight = try coordinator.latestHeight()
        try coordinator.stageBlockCreate(height: latestHeight)
        try coordinator.stageTransaction(try RawTransaction(serializedData: txData), at:  latestHeight + 1)
        try coordinator.applyStaged(blockheight: latestHeight + 1)
        
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            XCTAssertEqual(presendBalance - self.sendAmount,synchronizer.initializer.getBalance())
            XCTAssertEqual(presendBalance - self.sendAmount,synchronizer.initializer.getVerifiedBalance ())
            mineExpectation.fulfill()
            
        }, error: { (error) in
            guard let e = error else {
                XCTFail("unknown error syncing after sending transaction")
                return
            }
            
            XCTFail("Error: \(e)")
        })
        
        wait(for: [mineExpectation], timeout: 2)
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
        
        try coordinator.sync(completion: { (synchronizer) in
            syncedSynchronizer = syncedSynchronizer
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let synchronizer = syncedSynchronizer, let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create synchronizer")
            return
        }
        
        let presendBalance = synchronizer.initializer.getVerifiedBalance()
        XCTAssertTrue(presendBalance >= (Int64(ZcashSDK.MINERS_FEE_ZATOSHI) + sendAmount))  // there's more zatoshi to send than network fee
        
        var pendingTx: PendingTransactionEntity?
        
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
                XCTAssertEqual(Int64(transaction.value), self.sendAmount)
                
                XCTAssertTrue(
                    self.totalBalanceValidation(totalBalance: synchronizer.initializer.getBalance(), previousTotalbalance: presendBalance, sentAmount: Int64(self.sendAmount))
                )
                XCTAssertNil(transaction.errorCode)
                pendingTx = transaction
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
        guard let tx = pendingTx, let txData = tx.raw else {
            XCTFail("pending transaction nil after send")
            return
        }
        let latestHeight = try coordinator.latestHeight()
        try coordinator.stageBlockCreate(height: latestHeight)
        try coordinator.stageTransaction(try RawTransaction(serializedData: txData), at:  latestHeight + 1)
        try coordinator.applyStaged(blockheight: latestHeight + 1)
        
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            XCTAssertEqual(presendBalance - self.sendAmount,synchronizer.initializer.getBalance())
            
            mineExpectation.fulfill()
            
        }, error: { (error) in
            guard let e = error else {
                XCTFail("unknown error syncing after sending transaction")
                return
            }
            
            XCTFail("Error: \(e)")
        })
        
        wait(for: [mineExpectation], timeout: 2)
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
        coordinator = try TestCoordinator(
            serviceType: .darksideLightwallet(threshold: .upTo(height: 663230), dataset: .default),
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
        
        try coordinator.sync(completion: { (syncronizer) in
            XCTAssertEqual(syncronizer.clearedTransactions.count, 5)
            XCTAssertEqual(syncronizer.initializer.getBalance(), 410000)
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
    }
    
    /**
     Verify change transactions
     
     This can be either a Wallet test or a Synchronizer test. The latter is supposed to be simpler because it involves no UI testing whatsoever.
     
     Precondition
     Librustzcash is ‘synced’ up to ‘current tip’
     Known list of expected transactions on the block range to sync the wallet up to.
     Known expected balance on the block range to sync the wallet up to.
     There’s a spendable note with value > send amount that generates change
     
     Action:
     Send amount to zAddr
     sync to minedHeight + 1
     
     Success Criteria:
     There’s a sent transaction matching the amount sent to the given zAddr
     minedHeight is not -1
     Balance meets verified Balance and total balance criteria
     There’s a change note of value (previous note value - sent amount)
     
     */
    func testVerifyChangeTransaction() throws {
        let sendExpectation = XCTestExpectation(description: "send expectation")
        let createToAddressExpectation = XCTestExpectation(description: "create to address")
        var sdkSynchronizer: SDKSynchronizer?
        
        try coordinator.setLatestHeight(height: defaultLatestHeight)
        /*
         sync to current tip
         */
        
        try coordinator.sync(completion: { (synchronizer) in
            self.syncedExpectation.fulfill()
            sdkSynchronizer = synchronizer
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 6)
        
        guard let syncedSynchronizer = sdkSynchronizer else {
            XCTFail("null synchronizer")
            return
        }
        
        let previousVerifiedBalance = syncedSynchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance = syncedSynchronizer.initializer.getBalance()
        
        guard let spendingKeys = coordinator.spendingKeys?.first else {
            XCTFail("null spending keys")
            return
        }
        
        /*
         Send
         */
        
        var pendingTx: PendingTransactionEntity?
        syncedSynchronizer.sendToAddress(spendingKey: spendingKeys, zatoshi: Int64(sendAmount), toAddress: testRecipientAddress, memo: "test memo \(self.description)", from: 0) { (sendResult) in
            switch sendResult {
            case .failure(let sendError):
                XCTFail("error sending \(sendError)")
            case .success(let tx):
                pendingTx = tx
            }
            
            sendExpectation.fulfill()
        }
        wait(for: [createToAddressExpectation], timeout: 11)
        
        let syncToMinedheightExpectation = XCTestExpectation(description: "sync to mined height + 1")
        
        /*
         include sent transaction in block
         */
        guard let tx = pendingTx, let txData = tx.raw else {
            XCTFail("pending transaction nil after send")
            return
        }
        let latestHeight = try coordinator.latestHeight()
        try coordinator.stageBlockCreate(height: latestHeight)
        try coordinator.stageTransaction(try RawTransaction(serializedData: txData), at:  latestHeight + 1)
        try coordinator.applyStaged(blockheight: latestHeight + 1)
        
        
        /*
         Sync to that block
         */
        try coordinator.sync(completion: { (synchronizer) in
            
            let confirmedTx: ConfirmedTransactionEntity!
            do {
                
                confirmedTx = try synchronizer.allClearedTransactions().first(where: { (confirmed) -> Bool in
                    confirmed.transactionEntity.transactionId == pendingTx?.transactionEntity.transactionId
                })
                
            } catch {
                XCTFail("Error  retrieving cleared transactions")
                return
            }
            
            /*
             There’s a sent transaction matching the amount sent to the given zAddr
             */
            
            XCTAssertEqual(Int64(confirmedTx.value), self.sendAmount)
            XCTAssertEqual(confirmedTx.toAddress, self.testRecipientAddress)
            
            let transactionId = confirmedTx.transactionIndex
            
            /*
             Find out what note was used
             */
            let sentNotesRepo = SentNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
            
            guard let sentNote = sentNotesRepo.sentNote(byTransactionId: transactionId) else {
                XCTFail("Could not finde sent note with transaction Id \(transactionId)")
                return
            }
            
            let receivedNotesRepo = ReceivedNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: syncedSynchronizer.initializer.dataDbURL.absoluteString, readonly: true))
            
            /*
             get change note
             */
            guard let receivedNote = receivedNotesRepo.receivedNote(byTransactionId: transactionId) else {
                XCTFail("Could not find received not with change for transaction Id \(transactionId)")
                return
            }
            
            /*
             There’s a change note of value (previous note value - sent amount)
             */
            XCTAssertEqual(Int64(sentNote.value) - self.sendAmount, Int64(receivedNote.value))
            
            
            /*
             Balance meets verified Balance and total balance criteria
             */
            XCTAssertTrue(
                self.verifiedBalanceValidation(
                    previousBalance: previousVerifiedBalance,
                    spentNoteValue: Int64(sentNote.value),
                    changeValue: Int64(receivedNote.value),
                    sentAmount: Int64(self.sendAmount),
                    currentVerifiedBalance: synchronizer.initializer.getVerifiedBalance())
            )
            
            XCTAssertTrue(
                self.totalBalanceValidation(totalBalance: synchronizer.initializer.getBalance(),
                                            previousTotalbalance: previousTotalBalance,
                                            sentAmount: Int64(self.sendAmount))
            )
            syncToMinedheightExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncToMinedheightExpectation], timeout: ZcashSDK.DEFAULT_POLL_INTERVAL * 2)
    }
    
    /**
     Verify transactions that expire are reflected accurately in balance
     This test requires the transaction to expire.
     
     How can we mock or cause this? Would createToAddress and faking a network submission through lightwalletService and syncing 10 more blocks work?
     
     Precondition:
     Account has spendable funds
     Librustzcash is ‘synced’ up to ‘current tip’ †
     Current tip can be scanned 10 blocks past the generated to be expired transaction
     
     Action:
     Sync to current tip
     Create transaction to zAddr
     Mock send success
     Sync 10 blocks more
     
     Success Criteria:
     There’s a pending transaction that has expired
     Total Balance is equal to total balance previously shown before sending the expired transaction
     Verified Balance is equal to verified balance previously shown before sending the expired transaction
     
     */
    func testVerifyBalanceAfterExpiredTransaction() throws {
        
        var syncedSynchronizer: SDKSynchronizer?
        
        try coordinator.sync(completion: { (syncronizer) in
            syncedSynchronizer = syncronizer
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 10)
        
        
        guard let sdkSynchronizer = syncedSynchronizer, let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("no synchronizer or spending keys")
            return
        }
        
        let previousVerifiedBalance = sdkSynchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance = sdkSynchronizer.initializer.getBalance()
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingTx: PendingTransactionEntity?
        sdkSynchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: sendAmount, toAddress: testRecipientAddress, memo: "test send \(self.description)", from: 0) { (result) in
            switch result {
            case .failure(let error):
                // balance should be the same as before sending if transaction failed
                XCTAssertEqual(sdkSynchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
                XCTAssertEqual(sdkSynchronizer.initializer.getBalance(), previousTotalBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let pending):
                pendingTx = pending
            }
        }
        wait(for: [sendExpectation], timeout: 11)
        
        guard let pendingTransaction = pendingTx else {
            XCTFail("No pending transaction")
            return
        }
        
        let expirationSyncExpectation = XCTestExpectation(description: "expiration sync expectation")
        let expiryHeight = pendingTransaction.expiryHeight
        
        try coordinator.setLatestHeight(height: expiryHeight)
        
        try coordinator.sync(completion: { (synchronizer) in
            
            /*
             Verified Balance is equal to verified balance previously shown before sending the expired transaction
             */
            XCTAssertEqual(synchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
            
            /*
             Total Balance is equal to total balance previously shown before sending the expired transaction
             */
            XCTAssertEqual(synchronizer.initializer.getBalance(), previousTotalBalance)
            
            let pendingRepo = PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: synchronizer.initializer.pendingDbURL.absoluteString))
            
            guard let expiredPending = try? pendingRepo.find(by: pendingTransaction.id!),
                let id = expiredPending.id,
                let sentExpired = try? synchronizer.allSentTransactions().first(where: { $0.id ==  id}) else {
                    XCTFail("expired transaction not found")
                    return
            }
            /*
             There’s a pending transaction that has expired
             */
            XCTAssertEqual(expiredPending.minedHeight, -1)
            XCTAssertEqual(sentExpired.expiryHeight,expiryHeight)
            XCTAssertEqual(Int64(sentExpired.value), self.sendAmount)
            
            expirationSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [expirationSyncExpectation], timeout: 10)
    }
    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
    
    /**
     check if (previous available funds - spent note + change) equals to (previous available funds - sent amount)
     */
    func verifiedBalanceValidation(previousBalance: Int64,
                                   spentNoteValue: Int64,
                                   changeValue: Int64,
                                   sentAmount: Int64,
                                   currentVerifiedBalance: Int64) -> Bool {
        //  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
        previousBalance - spentNoteValue + changeValue == currentVerifiedBalance - sentAmount
    }
    
    func totalBalanceValidation(totalBalance: Int64,
                                previousTotalbalance: Int64,
                                sentAmount: Int64) -> Bool {
        totalBalance == previousTotalbalance - sentAmount
    }
    
}
