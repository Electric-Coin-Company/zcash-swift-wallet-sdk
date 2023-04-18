//
//  AdvancedReOrgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/14/20.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class AdvancedReOrgTests: XCTestCase {
    let sendAmount = Zatoshi(1000)
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()
    var cancellables: [AnyCancellable] = []

    override func setUp() async throws {
        try await super.setUp()
        // don't use an exact birthday, users never do.
        self.coordinator = try await TestCoordinator(walletBirthday: birthday + 50, network: network)
        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        cancellables = []

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
    
    func handleReorg(event: CompactBlockProcessor.Event) {
        guard case let .handledReorg(reorgHeight, rewindHeight) = event else { return XCTFail("empty reorg event") }

        logger.debug("--- REORG DETECTED \(reorgHeight)--- RewindHeight: \(rewindHeight)", file: #file, function: #function, line: #line)

        XCTAssertEqual(reorgHeight, expectedReorgHeight)
        reorgExpectation.fulfill()
    }
    
    /// pre-condition: know balances before tx at received_Tx_height arrives
    /// 1. Setup w/ default dataset
    /// 2. applyStaged(received_Tx_height)
    /// 3. sync up to received_Tx_height
    /// 3a. verify that balance is previous balance + tx amount
    /// 4. get that transaction hex encoded data
    /// 5. stage 5 empty blocks w/heights received_Tx_height to received_Tx_height + 3
    /// 6. stage tx at received_Tx_height + 3
    /// 6a. applyheight(received_Tx_height + 1)
    /// 7. sync to received_Tx_height + 1
    /// 8. assert that reorg happened at received_Tx_height
    /// 9. verify that balance equals initial balance
    /// 10. sync up to received_Tx_height + 3
    /// 11. verify that balance equals initial balance + tx amount
    func testReOrgChangesInboundTxMinedHeight() async throws {
        await hookToReOrgNotification()
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        var shouldContinue = false
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance = Zatoshi(-1)
        var initialVerifiedBalance = Zatoshi(-1)
        self.expectedReorgHeight = receivedTxHeight + 1
        
        /*
        precondition:know balances before tx at received_Tx_height arrives
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight - 1)
        sleep(3)
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        var synchronizer: SDKSynchronizer?
        
        do {
            try await coordinator.sync(
                completion: { synchro in
                    synchronizer = synchro
                    initialVerifiedBalance = try await synchro.getShieldedVerifiedBalance()
                    initialTotalBalance = try await synchro.getShieldedBalance()
                    preTxExpectation.fulfill()
                    shouldContinue = true
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }
        
        wait(for: [preTxExpectation], timeout: 10)
        
        guard shouldContinue else {
            XCTFail("pre receive sync failed")
            return
        }
        
        /*
        2. applyStaged(received_Tx_height)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        sleep(2)
        
        /*
        3. sync up to received_Tx_height
        */
        let receivedTxExpectation = XCTestExpectation(description: "received tx")
        var receivedTxTotalBalance = Zatoshi(-1)
        var receivedTxVerifiedBalance = Zatoshi(-1)
        
        do {
            try await coordinator.sync(
                completion: { synchro in
                    synchronizer = synchro
                    receivedTxVerifiedBalance = try await synchro.getShieldedVerifiedBalance()
                    receivedTxTotalBalance = try await synchro.getShieldedBalance()
                    receivedTxExpectation.fulfill()
                }, error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        sleep(2)
        wait(for: [receivedTxExpectation], timeout: 10)
        
        guard let syncedSynchronizer = synchronizer else {
            XCTFail("nil synchronizer")
            return
        }
        sleep(5)
        guard let receivedTx = await syncedSynchronizer.receivedTransactions.first, receivedTx.minedHeight == receivedTxHeight else {
            XCTFail("did not receive transaction")
            return
        }
        
        /*
        3a. verify that balance is previous balance + tx amount
        */
        XCTAssertEqual(receivedTxTotalBalance, initialTotalBalance + receivedTx.value)
        XCTAssertEqual(receivedTxVerifiedBalance, initialVerifiedBalance)

        /*
        4. get that transaction hex encoded data
        */
        let receivedTxData = receivedTx.raw ?? Data()
        
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
        try coordinator.stageTransaction(receivedRawTx, at: reorgedTxheight)
        
        /*
        6a. applyheight(received_Tx_height + 1)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)

        /*
        7. sync to received_Tx_height + 1
        */
        let reorgSyncexpectation = XCTestExpectation(description: "reorg expectation")
        
        var afterReorgTxTotalBalance = Zatoshi(-1)
        var afterReorgTxVerifiedBalance = Zatoshi(-1)
        
        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    afterReorgTxTotalBalance = try await synchronizer.getShieldedBalance()
                    afterReorgTxVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                    reorgSyncexpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

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
        
        var finalReorgTxTotalBalance = Zatoshi(-1)
        var finalReorgTxVerifiedBalance = Zatoshi(-1)
        
        try coordinator.applyStaged(blockheight: reorgedTxheight + 1)
        sleep(3)
        
        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    finalReorgTxTotalBalance = try await synchronizer.getShieldedBalance()
                    finalReorgTxVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                    finalsyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [finalsyncExpectation], timeout: 5)
        sleep(3)
        
        guard let reorgedTx = await coordinator.synchronizer.receivedTransactions.first else {
            XCTFail("no transactions found")
            return
        }
        
        XCTAssertEqual(reorgedTx.minedHeight, reorgedTxheight)
        XCTAssertEqual(initialVerifiedBalance, finalReorgTxVerifiedBalance)
        XCTAssertEqual(initialTotalBalance + receivedTx.value, finalReorgTxTotalBalance)
    }
    
    /// An outbound, unconfirmed transaction in a specific block changes height in the event of a reorg
    ///
    ///
    /// The wallet handles this change, reflects it appropriately in local storage, and funds remain spendable post confirmation.
    ///
    /// Pre-conditions:
    /// - Wallet has spendable funds
    ///
    /// 1. Setup w/ default dataset
    /// 2. applyStaged(received_Tx_height)
    /// 3. sync up to received_Tx_height
    /// 4. create transaction
    /// 5. stage 10 empty blocks
    /// 6. submit tx at sentTxHeight
    ///   a. getIncomingTx
    ///   b. stageTransaction(sentTx, sentTxHeight)
    ///   c. applyheight(sentTxHeight + 1 )
    /// 7. sync to  sentTxHeight + 2
    /// 8. stage sentTx and otherTx at sentTxheight
    /// 9. applyStaged(sentTx + 2)
    /// 10. sync up to received_Tx_height + 2
    /// 11. verify that the sent tx is mined and balance is correct
    /// 12. applyStaged(sentTx + 10)
    /// 13. verify that there's no more pending transaction
    func testReorgChangesOutboundTxIndex() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188
        var initialTotalBalance = Zatoshi(-1)
        
        /*
        2. applyStaged(received_Tx_height)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        /*
        3. sync up to received_Tx_height
        */
        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    initialTotalBalance = try await synchronizer.getShieldedBalance()
                    preTxExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [preTxExpectation], timeout: 5)
        
        let sendExpectation = XCTestExpectation(description: "sendToAddress")
        var pendingEntity: PendingTransactionEntity?
        var testError: Error?
        let sendAmount = Zatoshi(10000)

        /*
        4. create transaction
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: coordinator.spendingKey,
                zatoshi: sendAmount,
                toAddress: try Recipient(Environment.testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "test transaction")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            testError = error
            XCTFail("error sending to address. Error: \(String(describing: error))")
        }
        
        wait(for: [sendExpectation], timeout: 2)

        guard let pendingTx = pendingEntity else {
            XCTFail("error sending to address. Error: \(String(describing: testError))")
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
        
        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    let pMinedHeight = await synchronizer.pendingTransactions.first?.minedHeight
                    XCTAssertEqual(pMinedHeight, sentTxHeight)
                    sentTxSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

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

        print("Starting after reorg sync")
        let afterReOrgExpectation = XCTestExpectation(description: "after ReOrg Expectation")
        do {
            try await coordinator.sync(
                completion: { synchronizer in
                    /*
                    11. verify that the sent tx is mined and balance is correct
                    */
                    let pMinedHeight = await synchronizer.pendingTransactions.first?.minedHeight
                    XCTAssertEqual(pMinedHeight, sentTxHeight)
                    // fee change on this branch
                    let expectedBalance = try await synchronizer.getShieldedBalance()
                    XCTAssertEqual(initialTotalBalance - sendAmount - Zatoshi(1000), expectedBalance)
                    afterReOrgExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

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
        do {
            try await coordinator.sync(
                completion: { _ in
                    lastSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [lastSyncExpectation], timeout: 5)

        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedPendingTransactionsCount = await coordinator.synchronizer.pendingTransactions.count
        XCTAssertEqual(expectedPendingTransactionsCount, 0)
        XCTAssertEqual(initialTotalBalance - pendingTx.value - Zatoshi(1000), expectedVerifiedBalance)

        let resultingBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(resultingBalance, expectedVerifiedBalance)
    }
    
    func testIncomingTransactionIndexChange() async throws {
        await hookToReOrgNotification()
        self.expectedReorgHeight = 663196
        self.expectedRewindHeight = 663175
        try coordinator.reset(saplingActivation: birthday, branchID: "2bb40e60", chainName: "main")
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeBefore))
        try coordinator.applyStaged(blockheight: 663195)
        sleep(1)
        let firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
        
        var preReorgTotalBalance = Zatoshi.zero
        var preReorgVerifiedBalance = Zatoshi.zero
        try await coordinator.sync(
            completion: { synchronizer in
                preReorgTotalBalance = try await synchronizer.getShieldedBalance()
                preReorgVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                firstSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 10)
        
        /*
        trigger reorg
        */
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeAfter))
        try coordinator.applyStaged(blockheight: 663200)
        
        sleep(1)
        
        let afterReorgSync = XCTestExpectation(description: "after reorg sync")
        
        var postReorgTotalBalance = Zatoshi.zero
        var postReorgVerifiedBalance = Zatoshi.zero
        try await coordinator.sync(
            completion: { synchronizer in
                postReorgTotalBalance = try await synchronizer.getShieldedBalance()
                postReorgVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                afterReorgSync.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [reorgExpectation, afterReorgSync], timeout: 30)
        
        XCTAssertEqual(postReorgVerifiedBalance, preReorgVerifiedBalance)
        XCTAssertEqual(postReorgTotalBalance, preReorgTotalBalance)
    }
    
    func testReOrgExpiresInboundTransaction() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight = BlockHeight(663188)
        try coordinator.applyStaged(blockheight: receivedTxHeight - 1)
        sleep(2)
        let expectation = XCTestExpectation(description: "sync to \(receivedTxHeight - 1) expectation")
        var initialBalance = Zatoshi(-1)
        var initialVerifiedBalance = Zatoshi(-1)

        try await coordinator.sync(
            completion: { synchronizer in
                initialBalance = try await synchronizer.getShieldedBalance()
                initialVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                expectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [expectation], timeout: 5)
        
        let afterTxHeight = receivedTxHeight + 1
        try coordinator.applyStaged(blockheight: afterTxHeight)
        sleep(2)
        let afterTxSyncExpectation = XCTestExpectation(description: "sync to \(afterTxHeight) expectation")
        
        var afterTxBalance = Zatoshi(-1)
        var afterTxVerifiedBalance = Zatoshi(-1)

        try await coordinator.sync(
            completion: { synchronizer in
                afterTxBalance = try await synchronizer.getShieldedBalance()
                afterTxVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                let receivedTransactions = await synchronizer.receivedTransactions
                XCTAssertNotNil(
                    receivedTransactions.first { $0.minedHeight == receivedTxHeight },
                    "Transaction not found at \(receivedTxHeight)"
                )
                afterTxSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [afterTxSyncExpectation], timeout: 10.0)
        
        XCTAssertEqual(initialVerifiedBalance, afterTxVerifiedBalance)
        XCTAssertNotEqual(initialBalance, afterTxBalance)
        
        let reorgSize: Int = 3
        let newBlocksCount: Int = 11 + reorgSize
        try coordinator.stageBlockCreate(height: receivedTxHeight - reorgSize, count: newBlocksCount + reorgSize)
        try coordinator.applyStaged(blockheight: receivedTxHeight + newBlocksCount - 1)
        
        sleep(2)
        let afterReorgExpectation = XCTestExpectation(description: "after reorg expectation")
        
        var afterReOrgBalance = Zatoshi(-1)
        var afterReOrgVerifiedBalance = Zatoshi(-1)

        try await coordinator.sync(
            completion: { synchronizer in
                afterReOrgBalance = try await synchronizer.getShieldedBalance()
                afterReOrgVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                let receivedTransactions = await synchronizer.receivedTransactions
                XCTAssertNil(
                    receivedTransactions.first { $0.minedHeight == receivedTxHeight },
                    "Transaction found at \(receivedTxHeight) after reorg"
                )
                afterReorgExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [afterReorgExpectation], timeout: 5)
        
        XCTAssertEqual(afterReOrgBalance, initialBalance)
        XCTAssertEqual(afterReOrgVerifiedBalance, initialVerifiedBalance)
    }
    
    /// Steps:
    /// 1.  sync up to an incoming transaction (incomingTxHeight + 1)
    /// 1a. save balances
    /// 2. stage 4 blocks from incomingTxHeight - 1 with different nonce
    /// 3. stage otherTx at incomingTxHeight
    /// 4. stage incomingTx at incomingTxHeight
    /// 5. applyHeight(incomingHeight + 3)
    /// 6. sync to latest height
    /// 7. check that balances still match
    func testReOrgChangesInboundTxIndexInBlock() async throws {
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        let incomingTxHeight = BlockHeight(663188)
        
        try coordinator.applyStaged(blockheight: incomingTxHeight + 1)

        sleep(1)
        
        /*
        1.  sync up to an incoming transaction (incomingTxHeight + 1)
        */
        let firstSyncExpectation = XCTestExpectation(description: "first sync test expectation")
        
        var initialBalance = Zatoshi(-1)
        var initialVerifiedBalance = Zatoshi(-1)
        var incomingTx: ZcashTransaction.Received!

        try await coordinator.sync(
            completion: { _ in
                firstSyncExpectation.fulfill()
            }, error: self.handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        /*
        1a. save balances
        */
        initialBalance = try await coordinator.synchronizer.getShieldedBalance()
        initialVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        incomingTx = await coordinator.synchronizer.receivedTransactions.first(where: { $0.minedHeight == incomingTxHeight })

        let txRawData = incomingTx.raw ?? Data()
        
        let rawTransaction = RawTransaction.with({ rawTx in
            rawTx.data = txRawData
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

        sleep(1)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")

        /*
        6. sync to latest height
        */
        try await coordinator.sync(
            completion: { _ in
                lastSyncExpectation.fulfill()
            }, error: self.handleError
        )
        
        /*
        7. check that balances still match
        */
        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(expectedVerifiedBalance, initialVerifiedBalance)
        XCTAssertEqual(expectedBalance, initialBalance)
        
        wait(for: [lastSyncExpectation], timeout: 30)
    }
    
    func testTxIndexReorg() async throws {
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeBefore))
        
        let txReorgHeight = BlockHeight(663195)
        let finalHeight = BlockHeight(663200)
        try coordinator.applyStaged(blockheight: txReorgHeight)
        sleep(1)

        let firstSyncExpectation = XCTestExpectation(description: "first sync test expectation")
        var initialBalance = Zatoshi(-1)
        var initialVerifiedBalance = Zatoshi(-1)

        try await coordinator.sync(
            completion: { synchronizer in
                initialBalance = try await synchronizer.getShieldedBalance()
                initialVerifiedBalance = try await synchronizer.getShieldedVerifiedBalance()
                firstSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txIndexChangeAfter))
        
        try coordinator.applyStaged(blockheight: finalHeight)
        sleep(1)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")
        
        try await coordinator.sync(
            completion: { _ in
                lastSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [lastSyncExpectation], timeout: 5)

        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(expectedBalance, initialBalance)
        XCTAssertEqual(expectedVerifiedBalance, initialVerifiedBalance)
    }

    /// A Re Org occurs and changes the height of an outbound transaction
    /// Pre-condition: Wallet has funds
    ///
    /// Steps:
    /// 1. create fake chain
    /// 1a. sync to latest height
    /// 2. send transaction to recipient address
    /// 3. getIncomingTransaction
    /// 4. stage transaction at sentTxHeight
    /// 5. applyHeight(sentTxHeight)
    /// 6. sync to latest height
    /// 6a. verify that there's a pending transaction with a mined height of sentTxHeight
    /// 7. stage 15  blocks from sentTxHeight
    /// 7. a stage sent tx to sentTxHeight + 2
    /// 8. applyHeight(sentTxHeight + 1) to cause a 1 block reorg
    /// 9. sync to latest height
    /// 10. verify that there's a pending transaction with -1 mined height
    /// 11. applyHeight(sentTxHeight + 2)
    /// 11a. sync to latest height
    /// 12. verify that there's a pending transaction with a mined height of sentTxHeight + 2
    /// 13. apply height(sentTxHeight + 15)
    /// 14. sync to latest height
    /// 15. verify that there's no pending transaction and that the tx is displayed on the sentTransactions collection
    func testReOrgChangesOutboundTxMinedHeight() async throws {
        await hookToReOrgNotification()

        /*
        1. create fake chain
        */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        
        try coordinator.applyStaged(blockheight: 663188)
        sleep(2)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        /*
        1a. sync to latest height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    firstSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [firstSyncExpectation], timeout: 5)
        
        sleep(1)
        let initialTotalBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        
        /*
        2. send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKey,
                zatoshi: Zatoshi(20000),
                toAddress: try Recipient(Environment.testRecipientAddress, network: self.network.networkType),
                memo: try Memo(string: "this is a test")
            )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            await handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard pendingEntity != nil else {
            XCTFail("no pending transaction after sending")
            try await coordinator.stop()
            return
        }

        /**
        3. getIncomingTransaction
        */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try await coordinator.stop()
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
        let secondSyncExpectation = XCTestExpectation(description: "after send expectation")
        
        do {
            try await coordinator.sync(
                completion: { _ in
                    secondSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [secondSyncExpectation], timeout: 5)

        var pendingTransactionsCount = await coordinator.synchronizer.pendingTransactions.count
        XCTAssertEqual(pendingTransactionsCount, 1)
        guard let afterStagePendingTx = await coordinator.synchronizer.pendingTransactions.first else {
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
        
        do {
            try await coordinator.sync(
                completion: { _ in
                    afterReorgExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [reorgExpectation, afterReorgExpectation], timeout: 5)
        
        /*
        10. verify that there's a pending transaction with -1 mined height
        */
        guard let newPendingTx = await coordinator.synchronizer.pendingTransactions.first else {
            XCTFail("No pending transaction")
            try await coordinator.stop()
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
        do {
            try await coordinator.sync(
                completion: { _ in
                    yetAnotherExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [yetAnotherExpectation], timeout: 5)
        
        /*
        12. verify that there's a pending transaction with a mined height of sentTxHeight + 2
        */
        pendingTransactionsCount = await coordinator.synchronizer.pendingTransactions.count
        XCTAssertEqual(pendingTransactionsCount, 1)
        guard let newlyPendingTx = try await coordinator.synchronizer.allPendingTransactions().first else {
            XCTFail("no pending transaction")
            try await coordinator.stop()
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
        do {
            try await coordinator.sync(
                completion: { _ in
                    thisIsTheLastExpectationIPromess.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [thisIsTheLastExpectationIPromess], timeout: 5)
        
        /*
        15. verify that there's no pending transaction and that the tx is displayed on the sentTransactions collection
        */
        let pendingTranscationsCount = await coordinator.synchronizer.pendingTransactions.count
        XCTAssertEqual(pendingTranscationsCount, 0)

        let sentTransactions = await coordinator.synchronizer.sentTransactions
            .first(
                where: { transaction in
                    return transaction.rawID == newlyPendingTx.rawTransactionId
                }
            )

        XCTAssertNotNil(
            sentTransactions,
            "Sent Tx is not on sent transactions"
        )

        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()

        XCTAssertEqual(
            initialTotalBalance - newlyPendingTx.value - Zatoshi(1000),
            expectedBalance
        )

        XCTAssertEqual(
            initialTotalBalance - newlyPendingTx.value - Zatoshi(1000),
            expectedVerifiedBalance
        )
    }

    /// Uses the zcash-hackworks data set.

    /// A Re Org occurs at 663195, and sweeps an Inbound Tx that appears later on the chain.
    /// Steps:
    /// 1. reset dlwd
    /// 2. load blocks from txHeightReOrgBefore
    /// 3. applyStaged(663195)
    /// 4. sync to latest height
    /// 5. get balances
    /// 6. load blocks from dataset txHeightReOrgBefore
    /// 7. apply stage 663200
    /// 8. sync to latest height
    /// 9. verify that the balance is equal to the one before the reorg
    func testReOrgChangesInboundMinedHeight() async throws {
        try coordinator.reset(saplingActivation: 663150, branchID: branchID, chainName: chainName)
        sleep(2)
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txHeightReOrgBefore))
        sleep(2)
        try coordinator.applyStaged(blockheight: 663195)
        sleep(2)
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        try await coordinator.sync(
            completion: { _ in
                firstSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        let initialBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        let initialVerifiedBalance: Zatoshi = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        guard let initialTxHeight = try await coordinator.synchronizer.allReceivedTransactions().first?.minedHeight else {
            XCTFail("no incoming transaction found!")
            return
        }
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txHeightReOrgAfter))
        
        sleep(5)
        
        try coordinator.applyStaged(blockheight: 663200)
        
        sleep(6)
        
        let afterReOrgExpectation = XCTestExpectation(description: "after reorg")
        try await coordinator.sync(
            completion: { _ in
                afterReOrgExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [afterReOrgExpectation], timeout: 5)
        
        guard let afterReOrgTxHeight = await coordinator.synchronizer.receivedTransactions.first?.minedHeight else {
            XCTFail("no incoming transaction found after re org!")
            return
        }

        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(initialVerifiedBalance, expectedVerifiedBalance)
        XCTAssertEqual(initialBalance, expectedBalance)
        XCTAssert(afterReOrgTxHeight > initialTxHeight)
    }

    /// Re Org removes incoming transaction and is never mined
    /// Steps:
    /// 1. sync prior to incomingTxHeight - 1 to get balances there
    /// 2. sync to latest height
    /// 3. cause reorg
    /// 4. sync to latest height
    /// 5. verify that reorg Happened at reorgHeight
    /// 6. verify that balances match initial balances
    // FIXME [#644]: Test works with lightwalletd v0.4.13 but is broken when using newer lightwalletd. More info is in #644.
    func testReOrgRemovesIncomingTxForever() async throws {
        await hookToReOrgNotification()
        try coordinator.reset(saplingActivation: 663150, branchID: branchID, chainName: chainName)
        
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txReOrgRemovesInboundTxBefore))
        
        let reorgHeight: BlockHeight = 663195
        self.expectedReorgHeight = reorgHeight
        self.expectedRewindHeight = reorgHeight - 10
        
        try coordinator.applyStaged(blockheight: reorgHeight - 1)
        
        sleep(2)
        let firstSyncExpectation = XCTestExpectation(description: "first sync")
        
        /**
        1. sync prior to incomingTxHeight - 1 to get balances there
        */
        try await coordinator.sync(
            completion: { _ in
                firstSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [firstSyncExpectation], timeout: 5)
        
        let initialTotalBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        let initialVerifiedBalance: Zatoshi = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        
        try coordinator.applyStaged(blockheight: reorgHeight)
        sleep(1)
        
        let secondSyncExpectation = XCTestExpectation(description: "second sync expectation")
        
        /**
        2. sync to latest height
        */
        try await coordinator.sync(
            completion: { _ in
                secondSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [secondSyncExpectation], timeout: 10)
        
        /**
        3. cause reorg
        */
        try coordinator.resetBlocks(dataset: .predefined(dataset: .txReOrgRemovesInboundTxAfter))
        
        try coordinator.applyStaged(blockheight: 663200)
        sleep(2)
        
        let afterReorgSyncExpectation = XCTestExpectation(description: "after reorg expectation")
        try await coordinator.sync(
            completion: { _ in
                afterReorgSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [afterReorgSyncExpectation], timeout: 5)

        let expectedVerifiedBalance = try await coordinator.synchronizer.getShieldedVerifiedBalance()
        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(initialVerifiedBalance, expectedVerifiedBalance)
        XCTAssertEqual(initialTotalBalance, expectedBalance)
    }
    
    /// Transaction was included in a block, and then is not included in a block after a reorg, and expires.
    /// Steps:
    /// 1. create fake chain
    /// 1a. sync to latest height
    /// 2. send transaction to recipient address
    /// 3. getIncomingTransaction
    /// 4. stage transaction at sentTxHeight
    /// 5. applyHeight(sentTxHeight)
    /// 6. sync to latest height
    /// 6a. verify that there's a pending transaction with a mined height of sentTxHeight
    /// 7. stage 15 blocks from sentTxHeigth to cause a reorg
    /// 8. sync to latest height
    /// 9. verify that there's an expired transaction as a pending transaction
    func testReOrgRemovesOutboundTxAndIsNeverMined() async throws {
        await hookToReOrgNotification()
        
        /*
        1. create fake chain
        */
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName)
        let sentTxHeight: BlockHeight = 663195
        try coordinator.applyStaged(blockheight: sentTxHeight - 1)
        
        sleep(2)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        1a. sync to latest height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    firstSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [firstSyncExpectation], timeout: 10)
        
        sleep(1)
        let initialTotalBalance: Zatoshi = try await coordinator.synchronizer.getShieldedBalance()
        
        let sendExpectation = XCTestExpectation(description: "send expectation")
        var pendingEntity: PendingTransactionEntity?
        
        /*
        2. send transaction to recipient address
        */
        do {
            let pendingTx = try await coordinator.synchronizer.sendToAddress(
                spendingKey: self.coordinator.spendingKey,
                zatoshi: Zatoshi(20000),
                toAddress: try Recipient(Environment.testRecipientAddress, network: self.network.networkType),
                memo: try! Memo(string: "this is a test")
        )
            pendingEntity = pendingTx
            sendExpectation.fulfill()
        } catch {
            await handleError(error)
        }
        
        wait(for: [sendExpectation], timeout: 11)
        
        guard pendingEntity != nil else {
            XCTFail("no pending transaction after sending")
            try await coordinator.stop()
            return
        }

        /**
        3. getIncomingTransaction
        */
        guard let incomingTx = try coordinator.getIncomingTransactions()?.first else {
            XCTFail("no incoming transaction")
            try await coordinator.stop()
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
        let secondSyncExpectation = XCTestExpectation(description: "after send expectation")
        
        do {
            try await coordinator.sync(
                completion: { _ in
                    secondSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [secondSyncExpectation], timeout: 5)
        let extraBlocks = 25
        try coordinator.stageBlockCreate(height: sentTxHeight, count: extraBlocks, nonce: 5)
        
        try coordinator.applyStaged(blockheight: sentTxHeight + 5)
        
        sleep(2)
        let reorgSyncExpectation = XCTestExpectation(description: "reorg sync expectation")
        
        do {
            try await coordinator.sync(
                completion: { _ in
                    reorgSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [reorgExpectation, reorgSyncExpectation], timeout: 5)
        
        guard let pendingTx = await coordinator.synchronizer.pendingTransactions.first else {
            XCTFail("no pending transaction after reorg sync")
            return
        }
        
        XCTAssertFalse(pendingTx.isMined)
        
        LoggerProxy.info("applyStaged(blockheight: \(sentTxHeight + extraBlocks - 1))")
        try coordinator.applyStaged(blockheight: sentTxHeight + extraBlocks - 1)
        
        sleep(2)
        
        let lastSyncExpectation = XCTestExpectation(description: "last sync expectation")
        
        do {
            try await coordinator.sync(
                completion: { _ in
                    lastSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [lastSyncExpectation], timeout: 5)

        let expectedBalance = try await coordinator.synchronizer.getShieldedBalance()
        XCTAssertEqual(expectedBalance, initialTotalBalance)
    }
    
    func testLongSync() async throws {
        await hookToReOrgNotification()
        
        /*
        1. create fake chain
        */
        let fullSyncLength = 100_000
    
        try FakeChainBuilder.buildChain(darksideWallet: coordinator.service, branchID: branchID, chainName: chainName, length: fullSyncLength)
        
        try coordinator.applyStaged(blockheight: birthday + fullSyncLength)
        
        sleep(20)
        
        let firstSyncExpectation = XCTestExpectation(description: "first sync")

        /*
        sync to latest height
        */
        do {
            try await coordinator.sync(
                completion: { _ in
                    firstSyncExpectation.fulfill()
                },
                error: self.handleError
            )
        } catch {
            await handleError(error)
        }

        wait(for: [firstSyncExpectation], timeout: 600)
        
        let latestScannedHeight = await coordinator.synchronizer.latestBlocksDataProvider.latestScannedHeight
        XCTAssertEqual(latestScannedHeight, birthday + fullSyncLength)
    }
    
    func handleError(_ error: Error?) async {
        _ = try? await coordinator.stop()
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
    
    func hookToReOrgNotification() async {
        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case .handledReorg: self?.handleReorg(event: event)
            default: break
            }
        }

        await coordinator.synchronizer.blockProcessor.updateEventClosure(identifier: "tests", closure: eventClosure)
    }
}
