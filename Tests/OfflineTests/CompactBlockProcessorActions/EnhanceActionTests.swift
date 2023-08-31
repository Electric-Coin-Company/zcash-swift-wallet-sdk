//
//  EnhanceActionTests.swift
//  
//
//  Created by Lukáš Korba on 19.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class EnhanceActionTests: ZcashTestCase {
    var underlyingDownloadRange: CompactBlockRange?
    var underlyingScanRange: CompactBlockRange?
    var underlyingEnhanceRange: CompactBlockRange?

    override func setUp() {
        super.setUp()
        
        underlyingDownloadRange = nil
        underlyingScanRange = nil
        underlyingEnhanceRange = nil
    }
    
    func testEnhanceAction_decideWhatToDoNext_NoDownloadAndScanRange() async throws {
        let enhanceAction = setupAction()

        let syncContext = setupActionContext()

        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 1)

        let acResult = nextContext.checkStateIs(.clearCache)
        XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
    }
    
    func testEnhanceAction_decideWhatToDoNext_NothingToDownloadAndScanLeft() async throws {
        let enhanceAction = setupAction()
        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))

        let syncContext = setupActionContext()

        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 2000)

        let acResult = nextContext.checkStateIs(.clearCache)
        XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
    }

    func testEnhanceAction_decideWhatToDoNext_UpdateChainTipExpected() async throws {
        let enhanceAction = setupAction()
        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))

        let syncContext = setupActionContext()

        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 1500)

        let acResult = nextContext.checkStateIs(.updateChainTip)
        XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
    }

    func testEnhanceAction_LastScanHeightNil() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()

        do {
            _ = try await enhanceAction.run(with: syncContext) { _ in }
            XCTFail("testEnhanceAction_LastScanHeightNil is expected to fail.")
        } catch ZcashError.compactBlockProcessorLastScannedHeight {
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_LastScanHeightNil is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_firstUnenhancedHeightNil() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 1

        do {
            let nextContext = try await enhanceAction.run(with: syncContext) { _ in }
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
            
            let acResult = nextContext.checkStateIs(.clearCache)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testEnhanceAction_NoEnhanceRange is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_NoEnhanceRange() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 1
        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: underlyingScanRange?.lowerBound,
            firstUnenhancedHeight: 2000
        )

        do {
            _ = try await enhanceAction.run(with: syncContext) { _ in }
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_NoEnhanceRange is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_1000BlocksConditionNotFulfilled() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 1000
        syncContext.lastEnhancedHeight = 1000
        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: 1000,
            firstUnenhancedHeight: 1000
        )

        do {
            _ = try await enhanceAction.run(with: syncContext) { _ in }
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_1000BlocksConditionNotFulfilled is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_EnhancementOfBlocksCalled_FoundTransactions() async throws {
        let blockEnhancerMock = BlockEnhancerMock()

        let transaction = ZcashTransaction.Overview(
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
        )
        
        blockEnhancerMock.enhanceAtDidEnhanceClosure = { _, didEnhance in
            await didEnhance(EnhancementProgress.zero)
            return [transaction]
        }
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 2000
        syncContext.lastEnhancedHeight = 1500
        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: 1,
            firstUnenhancedHeight: 1000
        )
        syncContext.updateLastEnhancedHeightClosure = { _ in }

        do {
            _ = try await enhanceAction.run(with: syncContext) { event in
                guard case let .foundTransactions(transactions, _) = event else {
                    XCTFail("Event is expected to be .foundTransactions but received \(event)")
                    return
                }
                XCTAssertTrue(transactions.count == 1)
                guard let receivedTransaction = transactions.first else {
                    XCTFail("Transaction.first is expected to pass.")
                    return
                }
                
                XCTAssertEqual(receivedTransaction.expiryHeight, transaction.expiryHeight, "ReceivedTransaction differs from mocked one.")
            }
        } catch {
            XCTFail("testEnhanceAction_EnhancementOfBlocksCalled_FoundTransactions is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_EnhancementOfBlocksCalled_minedTransaction() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        
        let transaction = ZcashTransaction.Overview(
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
        )
        
        blockEnhancerMock.enhanceAtDidEnhanceClosure = { _, didEnhance in
            await didEnhance(
                EnhancementProgress(
                    totalTransactions: 0,
                    enhancedTransactions: 0,
                    lastFoundTransaction: transaction,
                    range: 0...0,
                    newlyMined: true
                )
            )
            return nil
        }
        
        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 2000
        syncContext.lastEnhancedHeight = 1500
        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: 1,
            firstUnenhancedHeight: 1000
        )
        syncContext.updateLastEnhancedHeightClosure = { _ in }

        do {
            _ = try await enhanceAction.run(with: syncContext) { event in
                if case .progressPartialUpdate = event { return }

                guard case .minedTransaction(let minedTransaction) = event else {
                    XCTFail("Event is expected to be .minedTransaction but received \(event)")
                    return
                }
                XCTAssertEqual(minedTransaction.expiryHeight, transaction.expiryHeight, "MinedTransaction differs from mocked one.")
            }
        } catch {
            XCTFail("testEnhanceAction_EnhancementOfBlocksCalled_minedTransaction is not expected to fail. \(error)")
        }
    }

    func testEnhanceAction_EnhancementOfBlocksCalled_usingSmallRange_minedTransaction() async throws {
        let blockEnhancerMock = BlockEnhancerMock()

        let transaction = ZcashTransaction.Overview(
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
        )

        blockEnhancerMock.enhanceAtDidEnhanceClosure = { _, didEnhance in
            await didEnhance(
                EnhancementProgress(
                    totalTransactions: 0,
                    enhancedTransactions: 0,
                    lastFoundTransaction: transaction,
                    range: 0...0,
                    newlyMined: true
                )
            )
            return nil
        }

        let enhanceAction = setupAction(blockEnhancerMock)
        
        let syncContext = setupActionContext()
        syncContext.lastScannedHeight = 2000
        syncContext.lastEnhancedHeight = 1500
        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: 1,
            firstUnenhancedHeight: 1000
        )
        syncContext.updateLastEnhancedHeightClosure = { _ in }
        
        do {
            _ = try await enhanceAction.run(with: syncContext) { event in
                if case .progressPartialUpdate = event { return }

                guard case .minedTransaction(let minedTransaction) = event else {
                    XCTFail("Event is expected to be .minedTransaction but received \(event)")
                    return
                }
                XCTAssertEqual(minedTransaction.expiryHeight, transaction.expiryHeight, "MinedTransaction differs from mocked one.")
            }
        } catch {
            XCTFail("testEnhanceAction_EnhancementOfBlocksCalled_minedTransaction is not expected to fail. \(error)")
        }
    }
    
    private func setupActionContext() -> ActionContextMock {
        let syncContext = ActionContextMock.default()

        syncContext.underlyingSyncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: underlyingScanRange?.lowerBound,
            firstUnenhancedHeight: underlyingEnhanceRange?.lowerBound
        )

        return syncContext
    }
    
    private func setupAction(
        _ blockEnhancerMock: BlockEnhancerMock = BlockEnhancerMock(),
        _ transactionRepositoryMock: TransactionRepositoryMock = TransactionRepositoryMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> EnhanceAction {
        mockContainer.mock(type: BlockEnhancer.self, isSingleton: true) { _ in blockEnhancerMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return EnhanceAction(
            container: mockContainer,
            configProvider: CompactBlockProcessor.ConfigProvider(config: config)
        )
    }
}
