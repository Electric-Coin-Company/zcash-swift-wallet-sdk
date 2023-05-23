//
//  ChecksBeforeSyncActionTests.swift
//  
//
//  Created by Lukáš Korba on 22.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ChecksBeforeSyncActionTests: ZcashTestCase {
    var underlyingDownloadRange: CompactBlockRange?
    var underlyingScanRange: CompactBlockRange?
    var underlyingLatestScannedHeight: BlockHeight?
    var underlyingLatestDownloadedBlockHeight: BlockHeight?

    override func setUp() {
        super.setUp()
        
        underlyingDownloadRange = nil
        underlyingScanRange = nil
        underlyingLatestScannedHeight = nil
        underlyingLatestDownloadedBlockHeight = nil
    }
    
    func testChecksBeforeSyncAction_shouldClearBlockCacheAndUpdateInternalState_noDownloadNoScanRange() async throws {
        let checksBeforeSyncAction = setupAction()

        let syncRanges = setupSyncRanges()
        
        let latestScannedHeight = checksBeforeSyncAction.shouldClearBlockCacheAndUpdateInternalState(syncRange: syncRanges)
        XCTAssertNil(latestScannedHeight, "latestScannedHeight is expected to be nil.")
    }

    func testChecksBeforeSyncAction_shouldClearBlockCacheAndUpdateInternalState_nothingToClear() async throws {
        let checksBeforeSyncAction = setupAction()

        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingLatestScannedHeight = BlockHeight(2000)
        underlyingLatestDownloadedBlockHeight = BlockHeight(2000)
        
        let syncRanges = setupSyncRanges()

        let latestScannedHeight = checksBeforeSyncAction.shouldClearBlockCacheAndUpdateInternalState(syncRange: syncRanges)
        XCTAssertNil(latestScannedHeight, "latestScannedHeight is expected to be nil.")
    }
    
    func testChecksBeforeSyncAction_shouldClearBlockCacheAndUpdateInternalState_somethingToClear() async throws {
        let checksBeforeSyncAction = setupAction()

        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingLatestScannedHeight = BlockHeight(2000)
        underlyingLatestDownloadedBlockHeight = BlockHeight(1000)
        
        let syncRanges = setupSyncRanges()

        let latestScannedHeight = checksBeforeSyncAction.shouldClearBlockCacheAndUpdateInternalState(syncRange: syncRanges)
        XCTAssertNotNil(latestScannedHeight, "latestScannedHeight is not expected to be nil.")
    }
    
    func testChecksBeforeSyncAction_NextAction_ClearStorage() async throws {
        let compactBlockRepository = CompactBlockRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        compactBlockRepository.clearClosure = { }
        internalSyncProgressStorageMock.setForKeyClosure = { _, _ in }
        internalSyncProgressStorageMock.synchronizeClosure = { true }

        let checksBeforeSyncAction = setupAction(
            compactBlockRepository,
            internalSyncProgressStorageMock
        )

        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingLatestScannedHeight = BlockHeight(2000)
        underlyingLatestDownloadedBlockHeight = BlockHeight(1000)
        
        let syncContext = await setupActionContext()

        do {
            let nextContext = try await checksBeforeSyncAction.run(with: syncContext) { _ in }
            XCTAssertTrue(compactBlockRepository.clearCalled, "storage.clear() is expected to be called.")
            XCTAssertTrue(internalSyncProgressStorageMock.setForKeyCalled, "internalSyncProgress.set() is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .fetchUTXO,
                "nextContext after .checksBeforeSync is expected to be .fetchUTXO but received \(nextState)"
            )
        } catch {
            XCTFail("testChecksBeforeSyncAction_NextAction_ClearStorage is not expected to fail. \(error)")
        }
    }
    
    func testChecksBeforeSyncAction_NextAction_CreateStorage() async throws {
        let compactBlockRepository = CompactBlockRepositoryMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        
        compactBlockRepository.createClosure = { }

        let checksBeforeSyncAction = setupAction(compactBlockRepository)
        
        let syncContext = await setupActionContext()

        do {
            let nextContext = try await checksBeforeSyncAction.run(with: syncContext) { _ in }
            XCTAssertTrue(compactBlockRepository.createCalled, "storage.create() is expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForKeyCalled, "internalSyncProgress.set() is not expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .fetchUTXO,
                "nextContext after .checksBeforeSync is expected to be .fetchUTXO but received \(nextState)"
            )
        } catch {
            XCTFail("testChecksBeforeSyncAction_NextAction_CreateStorage is not expected to fail. \(error)")
        }
    }

    private func setupAction(
        _ compactBlockRepositoryMock: CompactBlockRepositoryMock = CompactBlockRepositoryMock(),
        _ internalSyncProgressStorageMock: InternalSyncProgressStorageMock = InternalSyncProgressStorageMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ChecksBeforeSyncAction {
        mockContainer.register(type: InternalSyncProgress.self, isSingleton: true) { di in
            InternalSyncProgress(alias: .default, storage: internalSyncProgressStorageMock, logger: loggerMock)
        }

        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in compactBlockRepositoryMock }
        
        return ChecksBeforeSyncAction(
            container: mockContainer
        )
    }
    
    private func setupSyncRanges() -> SyncRanges {
        SyncRanges(
            latestBlockHeight: 0,
            downloadRange: underlyingDownloadRange,
            scanRange: underlyingScanRange,
            enhanceRange: nil,
            fetchUTXORange: nil,
            latestScannedHeight: underlyingLatestScannedHeight,
            latestDownloadedBlockHeight: underlyingLatestDownloadedBlockHeight
        )
    }
    
    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .checksBeforeSync)
        
        await syncContext.update(syncRanges: setupSyncRanges())
        await syncContext.update(totalProgressRange: CompactBlockRange(uncheckedBounds: (1000, 2000)))

        return syncContext
    }
}
