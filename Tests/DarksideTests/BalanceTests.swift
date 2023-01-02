//
//  BalanceTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/28/20.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable type_body_length implicitly_unwrapped_optional force_unwrapping file_length
class BalanceTests: XCTestCase {
    // TODO: Parameterize this from environment?
    // swiftlint:disable:next line_length
    let seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"

    // TODO: Parameterize this from environment
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"
    let sendAmount = Zatoshi(1000)
    let defaultLatestHeight: BlockHeight = 663188
    let branchID = "2bb40e60"
    let chainName = "main"
    let network: ZcashNetwork = DarksideWalletDNetwork()

    var birthday: BlockHeight = 663150
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var syncedExpectation = XCTestExpectation(description: "synced")
    var coordinator: TestCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            seed: self.seedPhrase,
            walletBirthday: self.birthday,
            channelProvider: ChannelProvider(),
            network: self.network
        )

        try coordinator.reset(saplingActivation: 663150, branchID: "e9ff75a6", chainName: "main")
    }
    
    /**
    verify that when sending the maximum amount, the transactions are broadcasted properly
    */
    func testMaxAmountSend() async throws {
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
                try coordinator.sync(completion: { synchronizer in
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
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }

        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: maxBalance,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
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
            let foundTx = txs.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
            XCTAssertNotNil(foundTx)
            XCTAssertEqual(foundTx?.minedHeight, sentTxHeight)
            
            foundTransactionsExpectation.fulfill()
        }
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 100)
        sleep(1)
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight)
        sleep(2) // add enhance breakpoint here
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
                        let pendingEntity = synchronizer.pendingTransactions.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
                        XCTAssertNotNil(pendingEntity, "pending transaction should have been mined by now")
                        XCTAssertTrue(pendingEntity?.isMined ?? false)
                        XCTAssertEqual(pendingEntity?.minedHeight, sentTxHeight)
                        mineExpectation.fulfill()
                        continuation.resume()
                    }, error: { error in
                        guard let error = error else {
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
        
        let confirmExpectation = XCTestExpectation(description: "confirm expectation")
        notificationHandler.transactionsFound = { txs in
            XCTFail("We shouldn't find any transactions at this point but found \(txs)")
        }
        notificationHandler.synchronizerMinedTransaction = { transaction in
            XCTFail("We shouldn't find any mined transactions at this point but found \(transaction)")
        }
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    confirmExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        wait(for: [confirmExpectation], timeout: 5)
        
        let confirmedPending = try coordinator.synchronizer.allPendingTransactions()
            .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        
        XCTAssertNil(confirmedPending, "pending, now confirmed transaction found")
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), .zero)
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), .zero)
    }
    
    /**
    verify that when sending the maximum amount minus one zatoshi, the transactions are broadcasted properly
    */
    func testMaxAmountMinusOneSend() async throws {
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
                try coordinator.sync(completion: { synchronizer in
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
        
        let maxBalanceMinusOne = verifiedBalance - network.constants.defaultFee(for: defaultLatestHeight) - Zatoshi(1)
        
        // 3 create a transaction for the max amount possible
        // 4 send the transaction
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        
        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: maxBalanceMinusOne,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "\(self.description) \(Date().description)")
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
            let foundTx = txs.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
            XCTAssertNotNil(foundTx)
            XCTAssertEqual(foundTx?.minedHeight, sentTxHeight)
            
            foundTransactionsExpectation.fulfill()
        }
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 100)
        sleep(1)
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight)
        sleep(2) // add enhance breakpoint here
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
                        let pendingEntity = synchronizer.pendingTransactions.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
                        XCTAssertNotNil(pendingEntity, "pending transaction should have been mined by now")
                        XCTAssertTrue(pendingEntity?.isMined ?? false)
                        XCTAssertEqual(pendingEntity?.minedHeight, sentTxHeight)
                        mineExpectation.fulfill()
                        continuation.resume()
                    }, error: { error in
                        guard let error = error else {
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
        
        let confirmExpectation = XCTestExpectation(description: "confirm expectation")
        notificationHandler.transactionsFound = { txs in
            XCTFail("We shouldn't find any transactions at this point but found \(txs)")
        }
        notificationHandler.synchronizerMinedTransaction = { transaction in
            XCTFail("We shouldn't find any mined transactions at this point but found \(transaction)")
        }
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    confirmExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [confirmExpectation], timeout: 5)
        
        let confirmedPending = try coordinator.synchronizer
            .allPendingTransactions()
            .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        
        XCTAssertNil(confirmedPending, "pending, now confirmed transaction found")
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), Zatoshi(1))
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), Zatoshi(1))
    }
    
    /**
    verify that when sending the a no change transaction, the transactions are broadcasted properly
    */
    func testSingleNoteNoChangeTransaction() async throws {
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
                try coordinator.sync(completion: { synchronizer in
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
        
        let maxBalanceMinusOne = Zatoshi(100000) - network.constants.defaultFee(for: defaultLatestHeight)
        
        // 3 create a transaction for the max amount possible
        // 4 send the transaction
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: maxBalanceMinusOne,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
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
            let foundTx = txs.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
            XCTAssertNotNil(foundTx)
            XCTAssertEqual(foundTx?.minedHeight, sentTxHeight)
            
            foundTransactionsExpectation.fulfill()
        }
        try coordinator.stageBlockCreate(height: sentTxHeight, count: 100)
        sleep(1)
        try coordinator.stageTransaction(rawTx, at: sentTxHeight)
        try coordinator.applyStaged(blockheight: sentTxHeight)
        sleep(2) // add enhance breakpoint here
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
                        let pendingEntity = synchronizer.pendingTransactions.first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
                        XCTAssertNotNil(pendingEntity, "pending transaction should have been mined by now")
                        XCTAssertTrue(pendingEntity?.isMined ?? false)
                        XCTAssertEqual(pendingEntity?.minedHeight, sentTxHeight)
                        mineExpectation.fulfill()
                        continuation.resume()
                    }, error: { error in
                        guard let error = error else {
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
        
        let confirmExpectation = XCTestExpectation(description: "confirm expectation")
        notificationHandler.transactionsFound = { txs in
            XCTFail("We shouldn't find any transactions at this point but found \(txs)")
        }
        notificationHandler.synchronizerMinedTransaction = { transaction in
            XCTFail("We shouldn't find any mined transactions at this point but found \(transaction)")
        }
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    confirmExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [confirmExpectation], timeout: 5)
        
        let confirmedPending = try coordinator.synchronizer
            .allPendingTransactions()
            .first(where: { $0.rawTransactionId == pendingTx.rawTransactionId })
        
        XCTAssertNil(confirmedPending, "pending, now confirmed transaction found")
        
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), Zatoshi(100000))
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), Zatoshi(100000))
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
    // swiftlint:disable cyclomatic_complexity
    func testVerifyAvailableBalanceDuringSend() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)

        sleep(1)
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    self.syncedExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [syncedExpectation], timeout: 60)
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        
        let presendVerifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        
        /*
        there's more zatoshi to send than network fee
        */
        XCTAssertTrue(presendVerifiedBalance >= network.constants.defaultFee(for: defaultLatestHeight) + sendAmount)
        
        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: sendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingTx = transaction
            self.sentTransactionExpectation.fulfill()
        } catch {
            /*
             balance should be the same as before sending if transaction failed
             */
            XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), presendVerifiedBalance)
            XCTFail("sendToAddress failed: \(error)")

        }
        
        XCTAssertTrue(coordinator.synchronizer.initializer.getVerifiedBalance() > .zero)
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
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
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
        
        wait(for: [mineExpectation], timeout: 5)
        
        XCTAssertEqual(
            presendVerifiedBalance - self.sendAmount - network.constants.defaultFee(for: defaultLatestHeight),
            coordinator.synchronizer.initializer.getBalance()
        )
        
        XCTAssertEqual(
            presendVerifiedBalance - self.sendAmount - network.constants.defaultFee(for: defaultLatestHeight),
            coordinator.synchronizer.initializer.getVerifiedBalance()
        )
        
        guard let transaction = pendingTx else {
            XCTFail("pending transaction nil")
            return
        }

        /*
        basic health check
        */
        XCTAssertEqual(transaction.value, self.sendAmount)
        
        /*
        build up repos to get data
        */
        guard let txid = transaction.rawTransactionId else {
            XCTFail("sent transaction has no internal id")
            return
        }

        let sentNoteDAO = SentNotesSQLDAO(
            dbProvider: SimpleConnectionProvider(
                path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString,
                readonly: true
            )
        )
        
        let receivedNoteDAO = ReceivedNotesSQLDAO(
            dbProvider: SimpleConnectionProvider(
                path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString,
                readonly: true
            )
        )
        var sentEntity: SentNoteEntity?
        do {
            sentEntity = try sentNoteDAO.sentNote(byRawTransactionId: txid)
        } catch {
            XCTFail("error retrieving sent note: \(error)")
        }
        
        guard let sentNote = sentEntity else {
            XCTFail("could not find sent note for this transaction")
            return
        }

        var receivedEntity: ReceivedNoteEntity?
        
        do {
            receivedEntity = try receivedNoteDAO.receivedNote(byRawTransactionId: txid)
        } catch {
            XCTFail("error retrieving received note: \(error)")
        }
        
        guard let receivedNote = receivedEntity else {
            XCTFail("could not find sent note for this transaction")
            return
        }

        //  (previous available funds - spent note + change) equals to (previous available funds - sent amount)
        
        self.verifiedBalanceValidation(
            previousBalance: presendVerifiedBalance,
            spentNoteValue: Zatoshi(Int64(sentNote.value)),
            changeValue: Zatoshi(Int64(receivedNote.value)),
            sentAmount: self.sendAmount,
            currentVerifiedBalance: self.coordinator.synchronizer.initializer.getVerifiedBalance()
        )
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
    func testVerifyTotalBalanceDuringSend() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        
        sleep(2)
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    self.syncedExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [syncedExpectation], timeout: 5)
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("failed to create spending keys")
            return
        }
        
        let presendBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()

        // there's more zatoshi to send than network fee
        XCTAssertTrue(presendBalance >= network.constants.defaultFee(for: defaultLatestHeight) + sendAmount)
        var pendingTx: PendingTransactionEntity?
        
        var testError: Error?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: sendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "test send \(self.description) \(Date().description)")
            )
            pendingTx = transaction
            self.sentTransactionExpectation.fulfill()
        } catch {
            // balance should be the same as before sending if transaction failed
            testError = error
            XCTFail("sendToAddress failed: \(error)")
        }
        
        XCTAssertTrue(coordinator.synchronizer.initializer.getVerifiedBalance() > .zero)
        wait(for: [sentTransactionExpectation], timeout: 12)
        
        if let testError {
            XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), presendBalance)
            XCTFail("error: \(testError)")
            return
        }
        guard let transaction = pendingTx else {
            XCTFail("pending transaction nil after send")
            return
        }
        
        XCTAssertEqual(transaction.value, self.sendAmount)
        
        XCTAssertEqual(
            self.coordinator.synchronizer.initializer.getBalance(),
            presendBalance - self.sendAmount - network.constants.defaultFee(for: defaultLatestHeight)
        )
        
        XCTAssertNil(transaction.errorCode)
        
        let latestHeight = try coordinator.latestHeight()
        let sentTxHeight = latestHeight + 1
        try coordinator.stageBlockCreate(height: sentTxHeight)
        guard let rawTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction after send")
            return
        }
        
        try coordinator.stageTransaction(rawTx, at: latestHeight + 1)
        try coordinator.applyStaged(blockheight: latestHeight + 1)
        sleep(2)
        let mineExpectation = XCTestExpectation(description: "mineTxExpectation")
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(
                    completion: { synchronizer in
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
        
        wait(for: [mineExpectation], timeout: 5)
        
        XCTAssertEqual(
            presendBalance - self.sendAmount - network.constants.defaultFee(for: defaultLatestHeight),
            coordinator.synchronizer.initializer.getBalance()
        )
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
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        sleep(1)
        try coordinator.sync(completion: { _ in
            self.syncedExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [syncedExpectation], timeout: 5)
        
        XCTAssertEqual(coordinator.synchronizer.clearedTransactions.count, 2)
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), Zatoshi(200000))
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
    func testVerifyChangeTransaction() async throws {
        try FakeChainBuilder.buildSingleNoteChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: defaultLatestHeight)
        sleep(1)
        let sendExpectation = XCTestExpectation(description: "send expectation")
        let createToAddressExpectation = XCTestExpectation(description: "create to address")
        
        try coordinator.setLatestHeight(height: defaultLatestHeight)

        /*
        sync to current tip
        */
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    self.syncedExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        wait(for: [syncedExpectation], timeout: 6)
        
        let previousVerifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        
        guard let spendingKeys = coordinator.spendingKeys?.first else {
            XCTFail("null spending keys")
            return
        }
        
        /*
        Send
        */
        let memo = try Memo(string: "shielding is fun!")
        var pendingTx: PendingTransactionEntity?
        do {
            let transaction = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKeys,
                zatoshi: sendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: memo
            )
            pendingTx = transaction
            sendExpectation.fulfill()
        } catch {
            XCTFail("error sending \(error)")
        }
        wait(for: [createToAddressExpectation], timeout: 30)
        
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
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    let confirmedTx: ConfirmedTransactionEntity!
                    do {
                        confirmedTx = try synchronizer.allClearedTransactions().first(where: { confirmed -> Bool in
                            confirmed.transactionEntity.transactionId == pendingTx?.transactionEntity.transactionId
                        })
                    } catch {
                        XCTFail("Error  retrieving cleared transactions")
                        return
                    }

                    /*
                    There’s a sent transaction matching the amount sent to the given zAddr
                    */
                    XCTAssertEqual(confirmedTx.value, self.sendAmount)
                    XCTAssertEqual(confirmedTx.toAddress, self.testRecipientAddress)
                    let confirmedMemo = try confirmedTx.memo?.intoMemoBytes()?.intoMemo()
                    XCTAssertEqual(confirmedMemo, memo)

                    guard let transactionId = confirmedTx.rawTransactionId else {
                        XCTFail("no raw transaction id")
                        return
                    }

                    /*
                    Find out what note was used
                    */
                    let sentNotesRepo = SentNotesSQLDAO(
                        dbProvider: SimpleConnectionProvider(
                            path: synchronizer.initializer.dataDbURL.absoluteString,
                            readonly: true
                        )
                    )

                    guard let sentNote = try? sentNotesRepo.sentNote(byRawTransactionId: transactionId) else {
                        XCTFail("Could not find sent note with transaction Id \(transactionId)")
                        return
                    }

                    let receivedNotesRepo = ReceivedNotesSQLDAO(
                        dbProvider: SimpleConnectionProvider(
                            path: self.coordinator.synchronizer.initializer.dataDbURL.absoluteString,
                            readonly: true
                        )
                    )

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
                    XCTAssertEqual(
                        previousVerifiedBalance - self.sendAmount - self.network.constants.defaultFee(for: self.defaultLatestHeight),
                        Zatoshi(Int64(receivedNote.value))
                    )

                    /*
                    Balance meets verified Balance and total balance criteria
                    */
                    self.verifiedBalanceValidation(
                        previousBalance: previousVerifiedBalance,
                        spentNoteValue: Zatoshi(Int64(sentNote.value)),
                        changeValue: Zatoshi(Int64(receivedNote.value)),
                        sentAmount: self.sendAmount,
                        currentVerifiedBalance: synchronizer.initializer.getVerifiedBalance()
                    )

                    self.totalBalanceValidation(
                        totalBalance: synchronizer.initializer.getBalance(),
                        previousTotalbalance: previousTotalBalance,
                        sentAmount: self.sendAmount
                    )

                    syncToMinedheightExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
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
    func testVerifyBalanceAfterExpiredTransaction() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: self.defaultLatestHeight)
        sleep(2)
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    self.syncedExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [syncedExpectation], timeout: 5)
        
        guard let spendingKey = coordinator.spendingKeys?.first else {
            XCTFail("no synchronizer or spending keys")
            return
        }
        
        let previousVerifiedBalance: Zatoshi = coordinator.synchronizer.initializer.getVerifiedBalance()
        let previousTotalBalance: Zatoshi = coordinator.synchronizer.initializer.getBalance()
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingTx: PendingTransactionEntity?
        do {
            let pending = try await coordinator.synchronizer.sendToAddress(
                spendingKey: spendingKey,
                zatoshi: sendAmount,
                toAddress: try Recipient(testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "test send \(self.description)")
            )
            pendingTx = pending
        } catch {
            // balance should be the same as before sending if transaction failed
            XCTAssertEqual(self.coordinator.synchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
            XCTAssertEqual(self.coordinator.synchronizer.initializer.getBalance(), previousTotalBalance)
            XCTFail("sendToAddress failed: \(error)")
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
        try await withCheckedThrowingContinuation { continuation in
            do {
                try coordinator.sync(completion: { synchronizer in
                    expirationSyncExpectation.fulfill()
                    continuation.resume()
                }, error: self.handleError)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        wait(for: [expirationSyncExpectation], timeout: 5)
        
        /*
        Verified Balance is equal to verified balance previously shown before sending the expired transaction
        */
        XCTAssertEqual(coordinator.synchronizer.initializer.getVerifiedBalance(), previousVerifiedBalance)
        
        /*
        Total Balance is equal to total balance previously shown before sending the expired transaction
        */
        XCTAssertEqual(coordinator.synchronizer.initializer.getBalance(), previousTotalBalance)
        
        let pendingRepo = PendingTransactionSQLDAO(
            dbProvider: SimpleConnectionProvider(
                path: coordinator.synchronizer.initializer.pendingDbURL.absoluteString
            )
        )
        
        guard let expiredPending = try? pendingRepo.find(by: pendingTransaction.id!),
            let id = expiredPending.id else {
                XCTFail("pending transaction not found")
                return
        }
        
        /*
        there no sent transaction displayed
        */
        XCTAssertNil( try coordinator.synchronizer.allSentTransactions().first(where: { $0.id == id }))

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
    func verifiedBalanceValidation(
        previousBalance: Zatoshi,
        spentNoteValue: Zatoshi,
        changeValue: Zatoshi,
        sentAmount: Zatoshi,
        currentVerifiedBalance: Zatoshi
    ) {
        XCTAssertEqual(previousBalance - spentNoteValue + changeValue, currentVerifiedBalance - sentAmount)
    }
    
    func totalBalanceValidation(
        totalBalance: Zatoshi,
        previousTotalbalance: Zatoshi,
        sentAmount: Zatoshi
    ) {
        XCTAssertEqual(totalBalance, previousTotalbalance - sentAmount - network.constants.defaultFee(for: defaultLatestHeight))
    }
}

class SDKSynchonizerListener {
    var transactionsFound: (([ConfirmedTransactionEntity]) -> Void)?
    var synchronizerMinedTransaction: ((PendingTransactionEntity) -> Void)?
    
    func subscribeToSynchronizer(_ synchronizer: SDKSynchronizer) {
        NotificationCenter.default.addObserver(self, selector: #selector(txFound(_:)), name: .synchronizerFoundTransactions, object: synchronizer)
        NotificationCenter.default.addObserver(self, selector: #selector(txMined(_:)), name: .synchronizerMinedTransaction, object: synchronizer)
    }
    
    func unsubscribe() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func txFound(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let txs = notification.userInfo?[SDKSynchronizer.NotificationKeys.foundTransactions] as? [ConfirmedTransactionEntity] else {
                XCTFail("expected [ConfirmedTransactionEntity] array")
                return
            }
            
            self?.transactionsFound?(txs)
        }
    }
    
    @objc func txMined(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let transaction = notification.userInfo?[SDKSynchronizer.NotificationKeys.minedTransaction] as? PendingTransactionEntity else {
                XCTFail("expected transaction")
                return
            }
            
            self?.synchronizerMinedTransaction?(transaction)
        }
    }
}
