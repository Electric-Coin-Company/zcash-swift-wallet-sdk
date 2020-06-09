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
    let defaultLatestHeight: BlockHeight = 663188
    var coordinator: TestCoordinator!
    
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    override func setUpWithError() throws {
        
        coordinator = try TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider()
        )
        try coordinator.reset(saplingActivation: 663150)
        
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        
        
        try coordinator.sync(completion: { (synchronizer) in
            
            self.syncedExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        
        let presendBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        
        /*
         there's more zatoshi to send than network fee
         */
        XCTAssertTrue(presendBalance >= (Int64(ZcashSDK.MINERS_FEE_ZATOSHI) + sendAmount))
        
        var pendingTx: PendingTransactionEntity?
        coordinator.synchronizer.sendToAddress(spendingKey: spendingKey,
                                               zatoshi: Int64(sendAmount),
                                               toAddress: testRecipientAddress,
                                               memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let error):
                /*
                 balance should be the same as before sending if transaction failed
                 */
                XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), presendBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let transaction):
                
                pendingTx = transaction
                
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(coordinator.synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
        // sync and mine
        
        guard let rawTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction after")
            return
        }
        let latestHeight = try coordinator.latestHeight()
        let sentTxHeight = latestHeight + 1
        try coordinator.stageBlockCreate(height: sentTxHeight)
        
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight)
        sleep(1)
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            
            mineExpectation.fulfill()
            
        }, error: { (error) in
            guard let e = error else {
                XCTFail("unknown error syncing after sending transaction")
                return
            }
            
            XCTFail("Error: \(e)")
        })
        
        wait(for: [mineExpectation], timeout: 5)
        
        XCTAssertEqual(presendBalance - self.sendAmount,coordinator.synchronizer.initializer.getBalance())
        XCTAssertEqual(presendBalance - self.sendAmount,coordinator.synchronizer.initializer.getVerifiedBalance())
        
        guard let transaction = pendingTx else {
            XCTFail("pending transaction nil")
            return
        }
        /*
         basic health check
         */
        XCTAssertEqual(Int64(transaction.value), self.sendAmount)
        
        /*
         build up repos to get data
         */
        guard let txid = transaction.rawTransactionId else {
            XCTFail("sent transaction has no internal id")
            return
        }
        let sentNoteDAO = SentNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
        
        let receivedNoteDAO = ReceivedNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
        var s: SentNoteEntity?
        do {
            s = try sentNoteDAO.sentNote(byRawTransactionId: txid)
        } catch {
            XCTFail("error retrieving sent note: \(error)")
        }
        
        guard let sentNote = s else {
            XCTFail("could not find sent note for this transaction")
            return
        }
        var r: ReceivedNoteEntity?
        
        do {
            r = try receivedNoteDAO.receivedNote(byRawTransactionId: txid)
        } catch {
            XCTFail("error retrieving received note: \(error)")
        }
        
        guard let receivedNote = r else {
            XCTFail("could not find sent note for this transaction")
            return
        }
        //  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
        
        self.verifiedBalanceValidation(previousBalance: presendBalance,
                                       spentNoteValue:  Int64(sentNote.value),
                                       changeValue: Int64(receivedNote.value),
                                       sentAmount: Int64(self.sendAmount),
                                       currentVerifiedBalance: self.coordinator.synchronizer.initializer.getVerifiedBalance())
        
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        
        sleep(2)
        try coordinator.sync(completion: { (synchronizer) in
            self.syncedExpectation.fulfill()
        }, error: handleError)
        
        wait(for: [syncedExpectation], timeout: 5)
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        
        let presendBalance = coordinator.synchronizer.initializer.getBalance()
        XCTAssertTrue(presendBalance >= (Int64(ZcashSDK.MINERS_FEE_ZATOSHI) + sendAmount))  // there's more zatoshi to send than network fee
        
        var pendingTx: PendingTransactionEntity?
        
        var error: Error?
        coordinator.synchronizer.sendToAddress(spendingKey: spendingKey,
                                               zatoshi: Int64(sendAmount),
                                               toAddress: testRecipientAddress,
                                               memo: "test send \(self.description) \(Date().description)",
        from: 0) { result in
            switch result {
            case .failure(let e):
                // balance should be the same as before sending if transaction failed
                
                error = e
                XCTFail("sendToAddress failed: \(e)")
            case .success(let transaction):
                
                pendingTx = transaction
            }
            self.sentTransactionExpectation.fulfill()
        }
        
        XCTAssertTrue(coordinator.synchronizer.initializer.getVerifiedBalance() > 0)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
        if let e = error {
            XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), presendBalance)
            XCTFail("error: \(e)")
            return
        }
        guard let transaction = pendingTx else {
            XCTFail("pending transaction nil after send")
            return
        }
        
        XCTAssertEqual(Int64(transaction.value), self.sendAmount)
        
        XCTAssertEqual(self.coordinator.synchronizer.initializer.getBalance(), presendBalance - Int64(self.sendAmount))
        
        XCTAssertNil(transaction.errorCode)
        
        let latestHeight = try coordinator.latestHeight()
        let sentTxHeight = latestHeight + 1
        try coordinator.stageBlockCreate(height: sentTxHeight)
        guard let rawTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction after send")
            return
        }
        
        try coordinator.stageTransaction(rawTx, at:  latestHeight + 1)
        try coordinator.applyStaged(blockheight: latestHeight + 1)
        sleep(2)
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try coordinator.sync(completion: { (synchronizer) in
            mineExpectation.fulfill()
        }, error: { (error) in
            guard let e = error else {
                XCTFail("unknown error syncing after sending transaction")
                return
            }
            
            XCTFail("Error: \(e)")
        })
        
        wait(for: [mineExpectation], timeout: 5)
        
        XCTAssertEqual(presendBalance - self.sendAmount - Int64(ZcashSDK.MINERS_FEE_ZATOSHI),coordinator.synchronizer.initializer.getBalance())
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        try coordinator.sync(completion: { (syncronizer) in
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.clearedTransactions.count, 2)
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), 200000)
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        let sendExpectation = XCTestExpectation(description: "send expectation")
        let createToAddressExpectation = XCTestExpectation(description: "create to address")
        
        
        try coordinator.setLatestHeight(height: defaultLatestHeight)
        /*
         sync to current tip
         */
        
        try coordinator.sync(completion: { (synchronizer) in
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 6)
        
        
        
        let previousVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance = coordinator.synchronizer.initializer.getBalance()
        
        guard let spendingKeys = coordinator.spendingKeys?.first else {
            XCTFail("null spending keys")
            return
        }
        
        /*
         Send
         */
        
        var pendingTx: PendingTransactionEntity?
        coordinator.synchronizer.sendToAddress(spendingKey: spendingKeys, zatoshi: Int64(sendAmount), toAddress: testRecipientAddress, memo: "test memo \(self.description)", from: 0) { (sendResult) in
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
        guard let rawTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("pending transaction nil after send")
            return
        }
        
        let latestHeight = try coordinator.latestHeight()
        let sentTxHeight = latestHeight + 1
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 12)
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight + 11  )
        sleep(2)
        
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
            
            guard let transactionId = confirmedTx.rawTransactionId else {
                XCTFail("no raw transaction id")
                return
            }
            
            /*
             Find out what note was used
             */
            let sentNotesRepo = SentNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
            
            guard let sentNote = try? sentNotesRepo.sentNote(byRawTransactionId: transactionId) else {
                XCTFail("Could not finde sent note with transaction Id \(transactionId)")
                return
            }
            
            let receivedNotesRepo = ReceivedNotesSQLDAO(dbProvider: SimpleConnectionProvider(path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString, readonly: true))
            
            /*
             get change note
             */
            guard let receivedNote = try? receivedNotesRepo.receivedNote(byRawTransactionId: transactionId) else {
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
            
            self.verifiedBalanceValidation(
                previousBalance: previousVerifiedBalance,
                spentNoteValue: Int64(sentNote.value),
                changeValue: Int64(receivedNote.value),
                sentAmount: Int64(self.sendAmount),
                currentVerifiedBalance: synchronizer.initializer.getVerifiedBalance())
            
            
            
            self.totalBalanceValidation(totalBalance: synchronizer.initializer.getBalance(),
                                        previousTotalbalance: previousTotalBalance,
                                        sentAmount: Int64(self.sendAmount))
            
            syncToMinedheightExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncToMinedheightExpectation], timeout: 5)
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
        
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service)
        
        try coordinator.applyStaged(blockheight: self.defaultLatestHeight)
        sleep(2)
        try coordinator.sync(completion: { (syncronizer) in
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 5)
        
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("no synchronizer or spending keys")
            return
        }
        
        let previousVerifiedBalance = coordinator.synchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance = coordinator.synchronizer.initializer.getBalance()
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingTx: PendingTransactionEntity?
        coordinator.synchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: sendAmount, toAddress: testRecipientAddress, memo: "test send \(self.description)", from: 0) { (result) in
            switch result {
            case .failure(let error):
                // balance should be the same as before sending if transaction failed
                XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
                XCTAssertEqual(self.coordinator.synchronizer.initializer.getBalance(), previousTotalBalance)
                XCTFail("sendToAddress failed: \(error)")
            case .success(let pending):
                pendingTx = pending
            }
        }
        wait(for: [sendExpectation], timeout: 12)
        
        guard let pendingTransaction = pendingTx, pendingTransaction.expiryHeight > defaultLatestHeight else {
            XCTFail("No pending transaction")
            return
        }
        
        let expirationSyncExpectation = XCTestExpectation(description: "expiration sync expectation")
        let expiryHeight = pendingTransaction.expiryHeight
        let blockCount = abs(self.defaultLatestHeight - expiryHeight)
        try coordinator.stageBlockCreate(height: self.defaultLatestHeight + 1, count: blockCount)
        try coordinator.applyStaged(blockheight: expiryHeight + 1)
        
        sleep(2)
        try coordinator.sync(completion: { (synchronizer) in
            expirationSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [expirationSyncExpectation], timeout: 5)
        
        /*
         Verified Balance is equal to verified balance previously shown before sending the expired transaction
         */
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
        
        /*
         Total Balance is equal to total balance previously shown before sending the expired transaction
         */
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), previousTotalBalance)
        
        let pendingRepo = PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: coordinator.synchronizer.initializer.pendingDbURL.absoluteString))
        
        guard let expiredPending = try? pendingRepo.find(by: pendingTransaction.id!),
            let id = expiredPending.id else {
                XCTFail("pending transaction not found")
                return
        }
        
        /*
         there no sent transaction displayed
         */
        
        XCTAssertNil( try coordinator.synchronizer.allSentTransactions().first(where: { $0.id ==  id}))
        /*
         There’s a pending transaction that has expired
         */
        XCTAssertEqual(expiredPending.minedHeight, -1)

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
                                   currentVerifiedBalance: Int64)  {
        //  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
        XCTAssertEqual(previousBalance - spentNoteValue + changeValue, currentVerifiedBalance - sentAmount)
    }
    
    func totalBalanceValidation(totalBalance: Int64,
                                previousTotalbalance: Int64,
                                sentAmount: Int64)  {
        XCTAssertEqual(totalBalance, previousTotalbalance - sentAmount - Int64(ZcashSDK.MINERS_FEE_ZATOSHI))
    }
    
}
