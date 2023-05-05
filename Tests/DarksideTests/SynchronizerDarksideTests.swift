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

class SynchronizerDarksideTests: XCTestCase {
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
    var foundTransactions: [ZcashTransaction.Overview] = []
    var cancellables: [AnyCancellable] = []
    var idGenerator: MockSyncSessionIDGenerator!

    override func setUp() async throws {
        try await super.setUp()
        idGenerator = MockSyncSessionIDGenerator(ids: [.deadbeef])
        self.coordinator = try await TestCoordinator(walletBirthday: birthday, network: network, syncSessionIDGenerator: idGenerator)
        try self.coordinator.reset(saplingActivation: 663150, branchID: "e9ff75a6", chainName: "main")
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        foundTransactions = []
        cancellables = []

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
    }
   
    func testFoundTransactions() async throws {
        coordinator.synchronizer.eventStream
            .map { event in
                guard case let .foundTransactions(transactions, _) = event else { return nil }
                return transactions
            }
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] transactions in self?.handleFoundTransactions(transactions: transactions) })
            .store(in: &cancellables)

        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188
    
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        try await coordinator.sync(
            completion: { _ in
                preTxExpectation.fulfill()
            },
            error: self.handleError
        )
        
        await fulfillment(of: [preTxExpectation], timeout: 5)
        
        XCTAssertEqual(self.foundTransactions.count, 2)
    }
    
    func testFoundManyTransactions() async throws {
        self.idGenerator.ids = [.deadbeef, .beefbeef, .beefdead]
        coordinator.synchronizer.eventStream
            .map { event in
                guard case let .foundTransactions(transactions, _) = event else { return nil }
                return transactions
            }
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] transactions in self?.handleFoundTransactions(transactions: transactions) })
            .store(in: &cancellables)
        
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName, length: 1000)
        let receivedTxHeight: BlockHeight = 663229
    
        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)
        
        sleep(2)
        let firsTxExpectation = XCTestExpectation(description: "first sync")

        try await coordinator.sync(
            completion: { _ in
                firsTxExpectation.fulfill()
            },
            error: self.handleError
        )
        
        await fulfillment(of: [firsTxExpectation], timeout: 10)
        
        XCTAssertEqual(self.foundTransactions.count, 5)
        
        self.foundTransactions.removeAll()
        
        try coordinator.applyStaged(blockheight: 663900)
        sleep(2)
        
        let preTxExpectation = XCTestExpectation(description: "intermediate sync")

        try await coordinator.sync(
            completion: { _ in
                preTxExpectation.fulfill()
            },
            error: self.handleError
        )
        
        await fulfillment(of: [preTxExpectation], timeout: 10)
        
        XCTAssertTrue(self.foundTransactions.isEmpty)
        
        let findManyTxExpectation = XCTestExpectation(description: "final sync")
        
        try coordinator.applyStaged(blockheight: 664010)
        sleep(2)
        
        try await coordinator.sync(
            completion: { _ in
                findManyTxExpectation.fulfill()
            },
            error: self.handleError
        )
        
        await fulfillment(of: [findManyTxExpectation], timeout: 10)
        
        XCTAssertEqual(self.foundTransactions.count, 2)
    }

    func testLastStates() async throws {
        self.idGenerator.ids = [.deadbeef, .beefbeef, .beefdead]
        let uuids = self.idGenerator.ids
        
        var cancellables: [AnyCancellable] = []

        var states: [SynchronizerState] = []

        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)

        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        coordinator.synchronizer.stateStream
            .sink { state in
                states.append(state)
            }
            .store(in: &cancellables)

        try await coordinator.sync(
            completion: { _ in
                preTxExpectation.fulfill()
            },
            error: self.handleError
        )

        await fulfillment(of: [preTxExpectation], timeout: 5)

        let expectedStates: [SynchronizerState] = [
            SynchronizerState(
                syncSessionID: .nullID,
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .disconnected,
                latestScannedHeight: 663150,
                latestBlockHeight: 0,
                latestScannedTime: 1576821833
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .syncing(BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0)),
                latestScannedHeight: 663150,
                latestBlockHeight: 0,
                latestScannedTime: 1576821833
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .syncing(BlockProgress(startHeight: 663150, targetHeight: 663189, progressHeight: 663189)),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .enhancing(EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0)),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .enhancing(
                    EnhancementProgress(
                        totalTransactions: 2,
                        enhancedTransactions: 1,
                        lastFoundTransaction: ZcashTransaction.Overview(
                            accountId: 0,
                            blockTime: 1.0,
                            expiryHeight: 663206,
                            fee: Zatoshi(0),
                            id: 2,
                            index: 1,
                            hasChange: false,
                            memoCount: 1,
                            minedHeight: 663188,
                            raw: Data(),
                            rawID: Data(),
                            receivedNoteCount: 1,
                            sentNoteCount: 0,
                            value: Zatoshi(100000),
                            isExpiredUmined: false
                        ),
                        range: 663150...663189
                    )
                ),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .enhancing(
                    EnhancementProgress(
                        totalTransactions: 2,
                        enhancedTransactions: 2,
                        lastFoundTransaction: ZcashTransaction.Overview(
                            accountId: 0,
                            blockTime: 1.0,
                            expiryHeight: 663192,
                            fee: Zatoshi(0),
                            id: 1,
                            index: 1,
                            hasChange: false,
                            memoCount: 1,
                            minedHeight: 663174,
                            raw: Data(),
                            rawID: Data(),
                            receivedNoteCount: 1,
                            sentNoteCount: 0,
                            value: Zatoshi(100000),
                            isExpiredUmined: false
                        ),
                        range: 663150...663189
                    )
                ),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .fetching,
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .synced,
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            )
        ]

        XCTAssertEqual(states.count, expectedStates.count)
        XCTAssertEqual(states[0], expectedStates[0])
        XCTAssertEqual(states[1], expectedStates[1])
        XCTAssertEqual(states[2], expectedStates[2])
        XCTAssertEqual(states[3], expectedStates[3])
        XCTAssertEqual(states[4], expectedStates[4])
        XCTAssertEqual(states[5], expectedStates[5])
        XCTAssertEqual(states[6], expectedStates[6])
        XCTAssertEqual(states[7], expectedStates[7])
    }

    func testSyncSessionUpdates() async throws {
        var cancellables: [AnyCancellable] = []

        self.idGenerator.ids = [.deadbeef, .beefbeef, .beefdead]
        let uuids = idGenerator.ids

        var states: [SynchronizerState] = []

        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)

        sleep(2)
        let preTxExpectation = XCTestExpectation(description: "pre receive")

        coordinator.synchronizer.stateStream
            .sink { state in
                states.append(state)
            }
            .store(in: &cancellables)

        try await coordinator.sync(
            completion: { _ in
                preTxExpectation.fulfill()
            },
            error: self.handleError
        )

        await fulfillment(of: [preTxExpectation], timeout: 5)

        let expectedStates: [SynchronizerState] = [
            SynchronizerState(
                syncSessionID: .nullID,
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .disconnected,
                latestScannedHeight: 663150,
                latestBlockHeight: 0,
                latestScannedTime: 1576821833.0
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .syncing(BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0)),
                latestScannedHeight: 663150,
                latestBlockHeight: 0,
                latestScannedTime: 1576821833.0
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: .zero,
                syncStatus: .syncing(BlockProgress(startHeight: 663150, targetHeight: 663189, progressHeight: 663189)),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .enhancing(EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0)),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .enhancing(
                    EnhancementProgress(
                        totalTransactions: 2,
                        enhancedTransactions: 1,
                        lastFoundTransaction: ZcashTransaction.Overview(
                            accountId: 0,
                            blockTime: 1.0,
                            expiryHeight: 663206,
                            fee: nil,
                            id: 2,
                            index: 1,
                            hasChange: false,
                            memoCount: 1,
                            minedHeight: 663188,
                            raw: Data(),
                            rawID: Data(),
                            receivedNoteCount: 1,
                            sentNoteCount: 0,
                            value: Zatoshi(100000),
                            isExpiredUmined: false
                        ),
                        range: 663150...663189
                    )
                ),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .enhancing(
                    EnhancementProgress(
                        totalTransactions: 2,
                        enhancedTransactions: 2,
                        lastFoundTransaction: ZcashTransaction.Overview(
                            accountId: 0,
                            blockTime: 1.0,
                            expiryHeight: 663192,
                            fee: nil,
                            id: 1,
                            index: 1,
                            hasChange: false,
                            memoCount: 1,
                            minedHeight: 663174,
                            raw: Data(),
                            rawID: Data(),
                            receivedNoteCount: 1,
                            sentNoteCount: 0,
                            value: Zatoshi(100000),
                            isExpiredUmined: false
                        ),
                        range: 663150...663189
                    )
                ),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .fetching,
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[0],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .synced,
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1
            )
        ]

        XCTAssertEqual(states.count, expectedStates.count)
        XCTAssertEqual(states[0], expectedStates[0])
        XCTAssertEqual(states[1], expectedStates[1])
        XCTAssertEqual(states[2], expectedStates[2])
        XCTAssertEqual(states[3], expectedStates[3])
        XCTAssertEqual(states[4], expectedStates[4])
        XCTAssertEqual(states[5], expectedStates[5])
        XCTAssertEqual(states[7], expectedStates[7])


        try coordinator.service.applyStaged(nextLatestHeight: 663_200)

        sleep(2)

        states.removeAll()

        let secondSyncExpectation = XCTestExpectation(description: "second sync")

        try await coordinator.sync(
            completion: { _ in
                secondSyncExpectation.fulfill()
            },
            error: self.handleError
        )

        await fulfillment(of: [secondSyncExpectation], timeout: 5)

        let secondBatchOfExpectedStates: [SynchronizerState] = [
            SynchronizerState(
                syncSessionID: uuids[1],
                shieldedBalance: WalletBalance(verified: Zatoshi(100000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .syncing(BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0)),
                latestScannedHeight: 663189,
                latestBlockHeight: 663189,
                latestScannedTime: 1.0
            ),
            SynchronizerState(
                syncSessionID: uuids[1],
                shieldedBalance: WalletBalance(verified: Zatoshi(200000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .syncing(BlockProgress(startHeight: 663190, targetHeight: 663200, progressHeight: 663200)),
                latestScannedHeight: 663200,
                latestBlockHeight: 663200,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[1],
                shieldedBalance: WalletBalance(verified: Zatoshi(200000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .enhancing(EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0)),
                latestScannedHeight: 663200,
                latestBlockHeight: 663200,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[1],
                shieldedBalance: WalletBalance(verified: Zatoshi(200000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .fetching,
                latestScannedHeight: 663200,
                latestBlockHeight: 663200,
                latestScannedTime: 1
            ),
            SynchronizerState(
                syncSessionID: uuids[1],
                shieldedBalance: WalletBalance(verified: Zatoshi(200000), total: Zatoshi(200000)),
                transparentBalance: WalletBalance(verified: Zatoshi(0), total: Zatoshi(0)),
                syncStatus: .synced,
                latestScannedHeight: 663200,
                latestBlockHeight: 663200,
                latestScannedTime: 1
            )
        ]

        XCTAssertEqual(states.count, secondBatchOfExpectedStates.count)
        XCTAssertEqual(states[0], secondBatchOfExpectedStates[0])
        XCTAssertEqual(states[1], secondBatchOfExpectedStates[1])
        XCTAssertEqual(states[2], secondBatchOfExpectedStates[2])
        XCTAssertEqual(states[3], secondBatchOfExpectedStates[3])
        XCTAssertEqual(states[4], secondBatchOfExpectedStates[4])

    }

    func testSyncAfterWipeWorks() async throws {
        idGenerator.ids = [.deadbeef, .beefbeef, .beefdead]
        try FakeChainBuilder.buildChain(darksideWallet: self.coordinator.service, branchID: branchID, chainName: chainName)
        let receivedTxHeight: BlockHeight = 663188

        try coordinator.applyStaged(blockheight: receivedTxHeight + 1)

        sleep(2)

        let firsSyncExpectation = XCTestExpectation(description: "first sync")

        try await coordinator.sync(
            completion: { _ in
                firsSyncExpectation.fulfill()
            },
            error: self.handleError
        )

        await fulfillment(of: [firsSyncExpectation], timeout: 10)

        let wipeFinished = XCTestExpectation(description: "SynchronizerWipeFinished Expectation")

        coordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        wipeFinished.fulfill()

                    case .failure(let error):
                        XCTFail("Wipe should finish successfully. \(error)")
                    }
                },
                receiveValue: {
                    XCTFail("No no value should be received from wipe.")
                }
            )
            .store(in: &cancellables)

        await fulfillment(of: [wipeFinished], timeout: 1)

        _ = try await coordinator.prepare(seed: Environment.seedBytes)

        let secondSyncExpectation = XCTestExpectation(description: "second sync")

        try await coordinator.sync(
            completion: { _ in
                secondSyncExpectation.fulfill()
            },
            error: self.handleError
        )

        await fulfillment(of: [secondSyncExpectation], timeout: 10)
    }
    
    func handleFoundTransactions(transactions: [ZcashTransaction.Overview]) {
        self.foundTransactions.append(contentsOf: transactions)
    }
    
    func handleError(_ error: Error?) async {
        _ = try? await coordinator.stop()
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

extension UUID {
    static let deadbeef = UUID(uuidString: "DEADBEEF-BEEF-FAFA-BEEF-FAFAFAFAFAFA")!
    static let beefbeef = UUID(uuidString: "BEEFBEEF-BEEF-DEAD-BEEF-BEEFEBEEFEBE")!
    static let beefdead = UUID(uuidString: "BEEFDEAD-BEEF-FAFA-DEAD-EAEAEAEAEAEA")!
}
