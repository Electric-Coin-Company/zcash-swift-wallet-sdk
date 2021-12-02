//
//  Z2TReceiveTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 8/4/21.
//

import XCTest
@testable import ZcashLightClientKit

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional
class Z2TReceiveTests: XCTestCase {
    // swiftlint:disable:next line_length
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" // TODO: Parameterize this from environment?
    
    let testRecipientAddress = "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz" // TODO: Parameterize this from environment
    
    let sendAmount: Int64 = 1000
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var foundTransactionsExpectation = XCTestExpectation(description: "found transactions")
    let branchID = "2bb40e60"
    let chainName = "main"
    
    let network = DarksideWalletDNetwork()
    
    override func setUpWithError() throws {
        try super.setUpWithError()

        coordinator = try TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider(),
            network: network
        )

        try coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()

        NotificationCenter.default.removeObserver(self)

        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
    
    func subscribeToFoundTransactions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(foundTransactions(_:)),
            name: .synchronizerFoundTransactions,
            object: nil
        )
    }
    
    @objc func foundTransactions(_ notification: Notification) {
        guard notification.userInfo?[SDKSynchronizer.NotificationKeys.foundTransactions] != nil else {
            XCTFail("found transactions notification is empty")
            return
        }
        self.foundTransactionsExpectation.fulfill()
    }
    
    func testFoundTransactions() throws {
        subscribeToFoundTransactions()
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        /*
        2. applyStaged(received_Tx_height)
        */
        try coordinator.applyStaged(blockheight: receivedTxHeight)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")
        
        /*
        3. sync up to received_Tx_height
        */
        try coordinator.sync(
            completion: { _ in
                preTxExpectation.fulfill()
            },
            error: self.handleError
        )
        
        wait(for: [preTxExpectation, foundTransactionsExpectation], timeout: 5)
        
        let sendExpectation = XCTestExpectation(description: "sendToAddress")
        var pendingEntity: PendingTransactionEntity?
        var error: Error?
        let sendAmount: Int64 = 10000
        /*
        4. create transaction
        */
        coordinator.synchronizer.sendToAddress(
            spendingKey: coordinator.spendingKeys!.first!,
            zatoshi: sendAmount,
            toAddress: testRecipientAddress,
            memo: "test transaction",
            from: 0
        ) { result in
            switch result {
            case .success(let pending):
                pendingEntity = pending
            case .failure(let e):
                error = e
            }
            sendExpectation.fulfill()
        }

        wait(for: [sendExpectation], timeout: 12)
        
        guard pendingEntity != nil else {
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
        self.foundTransactionsExpectation = XCTestExpectation(description: "inbound expectation")

        /*
        7. sync to  sentTxHeight + 1
        */
        let sentTxSyncExpectation = XCTestExpectation(description: "sent tx sync expectation")
        
        try coordinator.sync(completion: { synchronizer in
            let pMinedHeight = synchronizer.pendingTransactions.first?.minedHeight
            XCTAssertEqual(pMinedHeight, sentTxHeight)
            
            sentTxSyncExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [sentTxSyncExpectation, foundTransactionsExpectation], timeout: 5)
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
