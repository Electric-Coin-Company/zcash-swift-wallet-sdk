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
    var underlyingDownloadAndScanRange: CompactBlockRange?
    var underlyingEnhanceRange: CompactBlockRange?

    override func setUp() {
        super.setUp()
        
        underlyingDownloadAndScanRange = nil
        underlyingEnhanceRange = nil
    }
    
    func testEnhanceAction_decideWhatToDoNext_NoDownloadAndScanRange() async throws {
        let enhanceAction = setupAction()

        let syncContext = await setupActionContext()
        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 1)
        let nextState = await nextContext.state

        XCTAssertTrue(
            nextState == .clearCache,
            "testEnhanceAction_decideWhatToDoNext_NoDownloadAndScanRange is expected to be .clearCache but received \(nextState)"
        )
    }
    
    func testEnhanceAction_decideWhatToDoNext_NothingToDownloadAndScanLeft() async throws {
        let enhanceAction = setupAction()
        underlyingDownloadAndScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        
        let syncContext = await setupActionContext()
        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 2000)
        let nextState = await nextContext.state

        XCTAssertTrue(
            nextState == .clearCache,
            "testEnhanceAction_decideWhatToDoNext_NothingToDownloadAndScanLeft is expected to be .clearCache but received \(nextState)"
        )
    }

    func testEnhanceAction_decideWhatToDoNext_DownloadExpected() async throws {
        let enhanceAction = setupAction()
        underlyingDownloadAndScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        
        let syncContext = await setupActionContext()
        let nextContext = await enhanceAction.decideWhatToDoNext(context: syncContext, lastScannedHeight: 1500)
        let nextState = await nextContext.state

        XCTAssertTrue(
            nextState == .download,
            "testEnhanceAction_decideWhatToDoNext_DownloadExpected is expected to be .download but received \(nextState)"
        )
    }

    func testEnhanceAction_NoEnhanceRange() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1
        
        let enhanceAction = setupAction(
            blockEnhancerMock,
            transactionRepositoryMock,
            internalSyncProgressStorageMock
        )
        
        let syncContext = await setupActionContext()

        do {
            _ = try await enhanceAction.run(with: syncContext) { _ in }
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.integerForKeyCalled, "internalSyncProgress.load() is not expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_NoEnhanceRange is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_1000BlocksConditionNotFulfilled() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1
        internalSyncProgressStorageMock.integerForKeyReturnValue = 1
        
        let enhanceAction = setupAction(
            blockEnhancerMock,
            transactionRepositoryMock,
            internalSyncProgressStorageMock
        )
        
        underlyingEnhanceRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        
        let syncContext = await setupActionContext()

        do {
            _ = try await enhanceAction.run(with: syncContext) { _ in }
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(internalSyncProgressStorageMock.integerForKeyCalled, "internalSyncProgress.load() is expected to be called.")
            XCTAssertFalse(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is not expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_1000BlocksConditionNotFulfilled is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_EnhancementOfBlocksCalled_FoundTransactions() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1500
        internalSyncProgressStorageMock.integerForKeyReturnValue = 1
        
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
        
        let enhanceAction = setupAction(
            blockEnhancerMock,
            transactionRepositoryMock,
            internalSyncProgressStorageMock
        )
        
        underlyingEnhanceRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        
        let syncContext = await setupActionContext()

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
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(internalSyncProgressStorageMock.integerForKeyCalled, "internalSyncProgress.load() is expected to be called.")
            XCTAssertTrue(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_EnhancementOfBlocksCalled_FoundTransactions is not expected to fail. \(error)")
        }
    }
    
    func testEnhanceAction_EnhancementOfBlocksCalled_minedTransaction() async throws {
        let blockEnhancerMock = BlockEnhancerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1500
        internalSyncProgressStorageMock.integerForKeyReturnValue = 1
        
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
        
        let enhanceAction = setupAction(
            blockEnhancerMock,
            transactionRepositoryMock,
            internalSyncProgressStorageMock
        )
        
        underlyingEnhanceRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        
        let syncContext = await setupActionContext()

        do {
            _ = try await enhanceAction.run(with: syncContext) { event in
                guard case .minedTransaction(let minedTransaction) = event else {
                    XCTFail("Event is expected to be .minedTransaction but received \(event)")
                    return
                }
                XCTAssertEqual(minedTransaction.expiryHeight, transaction.expiryHeight, "MinedTransaction differs from mocked one.")
            }
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(internalSyncProgressStorageMock.integerForKeyCalled, "internalSyncProgress.load() is expected to be called.")
            XCTAssertTrue(blockEnhancerMock.enhanceAtDidEnhanceCalled, "blockEnhancer.enhance() is expected to be called.")
        } catch {
            XCTFail("testEnhanceAction_EnhancementOfBlocksCalled_minedTransaction is not expected to fail. \(error)")
        }
    }
    
    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .enhance)
        
        let syncRanges = SyncRanges(
            latestBlockHeight: 0,
            downloadRange: underlyingDownloadAndScanRange,
            scanRange: underlyingDownloadAndScanRange,
            enhanceRange: underlyingEnhanceRange,
            fetchUTXORange: nil,
            latestScannedHeight: nil,
            latestDownloadedBlockHeight: nil
        )
        
        await syncContext.update(syncRanges: syncRanges)
        await syncContext.update(totalProgressRange: CompactBlockRange(uncheckedBounds: (1000, 2000)))

        return syncContext
    }
    
    private func setupAction(
        _ blockEnhancerMock: BlockEnhancerMock = BlockEnhancerMock(),
        _ transactionRepositoryMock: TransactionRepositoryMock = TransactionRepositoryMock(),
        _ internalSyncProgressStorageMock: InternalSyncProgressStorageMock = InternalSyncProgressStorageMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> EnhanceAction {
        mockContainer.register(type: InternalSyncProgress.self, isSingleton: true) { _ in
            InternalSyncProgress(alias: .default, storage: internalSyncProgressStorageMock, logger: loggerMock)
        }
        
        mockContainer.mock(type: BlockEnhancer.self, isSingleton: true) { _ in blockEnhancerMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return EnhanceAction(
            container: mockContainer,
            config: config
        )
    }
}
