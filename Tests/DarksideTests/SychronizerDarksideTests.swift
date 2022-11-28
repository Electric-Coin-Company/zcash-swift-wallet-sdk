//
//  SychronizerDarksideTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 10/20/20.
//

import XCTest
import Combine
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional
class SychronizerDarksideTests: XCTestCase {
    // TODO: Parameterize this from environment?
    // swiftlint:disable:next line_length
    let seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"

    // TODO: Parameterize this from environment
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"
    let sendAmount: Int64 = 1000
    let defaultLatestHeight: BlockHeight = 663175
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()

    var birthday: BlockHeight = 663150
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    var foundTransactions: [ConfirmedTransactionEntity] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.coordinator = try TestCoordinator(
            seed: self.seedPhrase,
            walletBirthday: self.birthday,
            channelProvider: ChannelProvider(),
            network: self.network
        )

        try self.coordinator.reset(saplingActivation: 663150, branchID: "e9ff75a6", chainName: "main")
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        NotificationCenter.default.removeObserver(self)
        try coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }
   
    func testFoundTransactions() throws {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoundTransactions(_:)),
            name: Notification.Name.synchronizerFoundTransactions,
            object: nil
        )
        
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188
    
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        try coordinator.sync(completion: { _ in
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [preTxExpectation], timeout: 5)
        
        XCTAssertEqual(self.foundTransactions.count, 2)
    }
    
    func testFoundManyTransactions() throws {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoundTransactions(_:)),
            name: Notification.Name.synchronizerFoundTransactions,
            object: nil
        )
        
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName, length: 1000)
        let receivedTxHeight: BlockHeight = 663229
    
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)
        let firsTxExpectation = XCTestExpectation(description: "first sync")

        try coordinator.sync(completion: { _ in
            firsTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [firsTxExpectation], timeout: 10)
        
        XCTAssertEqual(self.foundTransactions.count, 5)
        
        self.foundTransactions.removeAll()
        
        try coordinator.applyStaged(blockheight: 663900)
        sleep(2)
        
        let preTxExpectation = XCTestExpectation(description: "intermediate sync")

        try coordinator.sync(completion: { _ in
            preTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [preTxExpectation], timeout: 10)
        
        XCTAssertTrue(self.foundTransactions.isEmpty)
        
        let findManyTxExpectation = XCTestExpectation(description: "final sync")
        
        try coordinator.applyStaged(blockheight: 664010)
        sleep(2)
        
        try coordinator.sync(completion: { _ in
            findManyTxExpectation.fulfill()
        }, error: self.handleError)
        
        wait(for: [findManyTxExpectation], timeout: 10)
        
        XCTAssertEqual(self.foundTransactions.count, 2)
    }

    func testLastStates() throws {

        var disposeBag = [AnyCancellable]()

        var states = [SDKSynchronizer.SynchronizerState]()

        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)

        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        coordinator.synchronizer.lastState
            .receive(on: DispatchQueue.main)
            .sink { state in
                states.append(state)
            }
            .store(in: &disposeBag)

        try coordinator.sync(completion: { _ in
            preTxExpectation.fulfill()
        }, error: self.handleError)

        wait(for: [preTxExpectation], timeout: 5)

        XCTAssertEqual(states, [
            SDKSynchronizer.SynchronizerState(
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .unprepared,
                latestScannedHeight: self.birthday
            ),
            SDKSynchronizer.SynchronizerState(
                shieldedBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: SyncStatus.disconnected,
                latestScannedHeight: 663150
            ),
            SDKSynchronizer.SynchronizerState(
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: SyncStatus.synced,
                latestScannedHeight: 663189
            )
        ])
    }
    
    @objc func handleFoundTransactions(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let transactions = userInfo[SDKSynchronizer.NotificationKeys.foundTransactions] as? [ConfirmedTransactionEntity]
        else {
            return
        }
        self.foundTransactions.append(contentsOf: transactions)
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


extension Zatoshi: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Zatoshi(\(self.amount))"
    }
}
