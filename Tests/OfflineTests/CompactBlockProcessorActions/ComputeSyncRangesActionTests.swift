//
//  ComputeSyncRangesActionTests.swift
//  
//
//  Created by Lukáš Korba on 22.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ComputeSyncRangesActionTests: ZcashTestCase {
    var underlyingDownloadRange: CompactBlockRange?
    var underlyingScanRange: CompactBlockRange?

    override func setUp() {
        super.setUp()
        
        underlyingDownloadRange = nil
        underlyingScanRange = nil
    }
    
    func testComputeSyncRangesAction_computeTotalProgressRange_noDownloadNoScanRange() async throws {
        let computeSyncRangesAction = setupAction()
        
        let syncRanges = setupSyncRanges()

        let totalProgressRange = computeSyncRangesAction.computeTotalProgressRange(from: syncRanges)

        XCTAssertTrue(
            totalProgressRange == 0...0,
            "testComputeSyncRangesAction_computeTotalProgressRange_noDownloadNoScanRange is expected to be 0...0 but received \(totalProgressRange)"
        )
    }

    func testComputeSyncRangesAction_computeTotalProgressRange_ValidRange() async throws {
        let computeSyncRangesAction = setupAction()

        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))

        let syncRanges = setupSyncRanges()
        let totalProgressRange = computeSyncRangesAction.computeTotalProgressRange(from: syncRanges)
        let expectedRange = 1000...2000
        
        XCTAssertTrue(
            totalProgressRange == expectedRange,
            "testComputeSyncRangesAction_computeTotalProgressRange_ValidRange is expected to be \(expectedRange) but received \(totalProgressRange)"
        )
    }
    
    func testComputeSyncRangesAction_finishProcessingCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        let loggerMock = LoggerMock()
        
        let computeSyncRangesAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            internalSyncProgressStorageMock,
            loggerMock
        )

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncRangesAction.run(with: syncContext) { _ in }

            XCTAssertTrue(
                blockDownloaderServiceMock.lastDownloadedBlockHeightCalled,
                "downloaderService.lastDownloadedBlockHeight() is expected to be called."
            )
            XCTAssertTrue(
                latestBlocksDataProviderMock.updateScannedDataCalled,
                "latestBlocksDataProvider.updateScannedData() is expected to be called."
            )
            XCTAssertTrue(latestBlocksDataProviderMock.updateBlockDataCalled, "latestBlocksDataProvider.updateBlockData() is expected to be called.")
            XCTAssertFalse(loggerMock.infoFileFunctionLineCalled, "logger.info() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .finished,
                "nextContext after .computeSyncRanges is expected to be .finished but received \(nextState)"
            )
        } catch {
            XCTFail("testComputeSyncRangesAction_finishProcessingCase is not expected to fail. \(error)")
        }
    }
    
    func testComputeSyncRangesAction_checksBeforeSyncCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        let loggerMock = LoggerMock()
        
        let computeSyncRangesAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            internalSyncProgressStorageMock,
            loggerMock
        )
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 10

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncRangesAction.run(with: syncContext) { _ in }

            XCTAssertTrue(
                blockDownloaderServiceMock.lastDownloadedBlockHeightCalled,
                "downloaderService.lastDownloadedBlockHeight() is expected to be called."
            )
            XCTAssertTrue(
                latestBlocksDataProviderMock.updateScannedDataCalled,
                "latestBlocksDataProvider.updateScannedData() is expected to be called."
            )
            XCTAssertTrue(latestBlocksDataProviderMock.updateBlockDataCalled, "latestBlocksDataProvider.updateBlockData() is expected to be called.")
            XCTAssertFalse(loggerMock.infoFileFunctionLineCalled, "logger.info() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .checksBeforeSync,
                "nextContext after .computeSyncRanges is expected to be .checksBeforeSync but received \(nextState)"
            )
        } catch {
            XCTFail("testComputeSyncRangesAction_checksBeforeSyncCase is not expected to fail. \(error)")
        }
    }
    
    func testComputeSyncRangesAction_waitCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()
        let loggerMock = LoggerMock()
        
        let computeSyncRangesAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            internalSyncProgressStorageMock,
            loggerMock
        )
        blockDownloaderServiceMock.lastDownloadedBlockHeightReturnValue = 10
        latestBlocksDataProviderMock.underlyingLatestScannedHeight = 10
        internalSyncProgressStorageMock.integerForKeyReturnValue = 10
        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in }

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncRangesAction.run(with: syncContext) { _ in }

            XCTAssertTrue(
                blockDownloaderServiceMock.lastDownloadedBlockHeightCalled,
                "downloaderService.lastDownloadedBlockHeight() is expected to be called."
            )
            XCTAssertTrue(
                latestBlocksDataProviderMock.updateScannedDataCalled,
                "latestBlocksDataProvider.updateScannedData() is expected to be called."
            )
            XCTAssertTrue(latestBlocksDataProviderMock.updateBlockDataCalled, "latestBlocksDataProvider.updateBlockData() is expected to be called.")
            XCTAssertTrue(loggerMock.infoFileFunctionLineCalled, "logger.info() is expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .finished,
                "nextContext after .computeSyncRanges is expected to be .finished but received \(nextState)"
            )
        } catch {
            XCTFail("testComputeSyncRangesAction_waitCase is not expected to fail. \(error)")
        }
    }

    private func setupSyncRanges() -> SyncRanges {
        SyncRanges(
            latestBlockHeight: 0,
            downloadRange: underlyingDownloadRange,
            scanRange: underlyingScanRange,
            enhanceRange: nil,
            fetchUTXORange: nil,
            latestScannedHeight: nil,
            latestDownloadedBlockHeight: nil
        )
    }
    
    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .computeSyncRanges)
        
        await syncContext.update(syncRanges: setupSyncRanges())
        await syncContext.update(totalProgressRange: CompactBlockRange(uncheckedBounds: (1000, 2000)))

        return syncContext
    }
    
    private func setupAction(
        _ blockDownloaderServiceMock: BlockDownloaderServiceMock = BlockDownloaderServiceMock(),
        _ latestBlocksDataProviderMock: LatestBlocksDataProviderMock = LatestBlocksDataProviderMock(),
        _ internalSyncProgressStorageMock: InternalSyncProgressStorageMock = InternalSyncProgressStorageMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ComputeSyncRangesAction {
        mockContainer.register(type: InternalSyncProgress.self, isSingleton: true) { _ in
            InternalSyncProgress(alias: .default, storage: internalSyncProgressStorageMock, logger: loggerMock)
        }

        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in blockDownloaderServiceMock }
        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in latestBlocksDataProviderMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return ComputeSyncRangesAction(
            container: mockContainer,
            configProvider: CompactBlockProcessor.ConfigProvider(config: config)
        )
    }
    
    private func setupDefaultMocksAndReturnAction(
        _ blockDownloaderServiceMock: BlockDownloaderServiceMock = BlockDownloaderServiceMock(),
        _ latestBlocksDataProviderMock: LatestBlocksDataProviderMock = LatestBlocksDataProviderMock(),
        _ internalSyncProgressStorageMock: InternalSyncProgressStorageMock = InternalSyncProgressStorageMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ComputeSyncRangesAction {
        blockDownloaderServiceMock.lastDownloadedBlockHeightReturnValue = 1
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 1
        latestBlocksDataProviderMock.underlyingLatestScannedHeight = 1
        latestBlocksDataProviderMock.updateScannedDataClosure = { }
        latestBlocksDataProviderMock.updateBlockDataClosure = { }
        internalSyncProgressStorageMock.integerForKeyReturnValue = 1
        internalSyncProgressStorageMock.boolForKeyReturnValue = true
        internalSyncProgressStorageMock.setBoolClosure = { _, _ in }
        internalSyncProgressStorageMock.synchronizeClosure = { true }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }
        
        return setupAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            internalSyncProgressStorageMock,
            loggerMock
        )
    }
}
