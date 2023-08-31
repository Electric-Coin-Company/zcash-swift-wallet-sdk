//
//  ComputeSyncControlDataActionTests.swift
//  
//
//  Created by Lukáš Korba on 22.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ComputeSyncControlDataActionTests: ZcashTestCase {
    var underlyingDownloadRange: CompactBlockRange?
    var underlyingScanRange: CompactBlockRange?

    override func setUp() {
        super.setUp()
        
        underlyingDownloadRange = nil
        underlyingScanRange = nil
    }
    
    func testComputeSyncControlDataAction_finishProcessingCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let loggerMock = LoggerMock()
        
        let computeSyncControlDataAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            loggerMock
        )
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 123
        latestBlocksDataProviderMock.underlyingLatestScannedHeight = 123

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncControlDataAction.run(with: syncContext) { _ in }

            checkLatestBlocksDataProvider(latestBlocksDataProviderMock)
            checkActionContext(nextContext, expectedNextState: .finished)
            
            XCTAssertTrue(loggerMock.debugFileFunctionLineCalled, "logger.debug() is expected to be called.")
        } catch {
            XCTFail("testComputeSyncControlDataAction_finishProcessingCase is not expected to fail. \(error)")
        }
    }
    
    func testComputeSyncControlDataAction_DownloadCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let loggerMock = LoggerMock()
        
        let computeSyncControlDataAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            loggerMock
        )
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 1234
        latestBlocksDataProviderMock.underlyingLatestScannedHeight = 123

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncControlDataAction.run(with: syncContext) { _ in }

            checkLatestBlocksDataProvider(latestBlocksDataProviderMock)
            checkActionContext(nextContext, expectedNextState: .download)

            XCTAssertTrue(loggerMock.debugFileFunctionLineCalled, "logger.debug() is expected to be called.")
        } catch {
            XCTFail("testComputeSyncControlDataAction_checksBeforeSyncCase is not expected to fail. \(error)")
        }
    }
    
    private func setupActionContext() async -> ActionContextMock {
        let syncContext = ActionContextMock()

        syncContext.updateLastScannedHeightClosure = { _ in }
        syncContext.updateLastDownloadedHeightClosure = { _ in }
        syncContext.updateSyncControlDataClosure = { _ in }
        syncContext.updateTotalProgressRangeClosure = { _ in }
        syncContext.updateStateClosure = { _ in }
        syncContext.underlyingState = .idle
        
        return syncContext
    }
    
    private func setupDefaultMocksAndReturnAction(
        _ blockDownloaderServiceMock: BlockDownloaderServiceMock = BlockDownloaderServiceMock(),
        _ latestBlocksDataProviderMock: LatestBlocksDataProviderMock = LatestBlocksDataProviderMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ComputeSyncControlDataAction {
        latestBlocksDataProviderMock.updateScannedDataClosure = { }
        latestBlocksDataProviderMock.updateBlockDataClosure = { }
        latestBlocksDataProviderMock.updateUnenhancedDataClosure = { }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }
        
        return setupAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            loggerMock
        )
    }
    
    private func setupAction(
        _ blockDownloaderServiceMock: BlockDownloaderServiceMock = BlockDownloaderServiceMock(),
        _ latestBlocksDataProviderMock: LatestBlocksDataProviderMock = LatestBlocksDataProviderMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ComputeSyncControlDataAction {
        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in blockDownloaderServiceMock }
        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in latestBlocksDataProviderMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return ComputeSyncControlDataAction(
            container: mockContainer,
            configProvider: CompactBlockProcessor.ConfigProvider(config: config)
        )
    }
    
    private func checkLatestBlocksDataProvider(_ latestBlocksDataProviderMock: LatestBlocksDataProviderMock) {
        XCTAssertTrue(
            latestBlocksDataProviderMock.updateScannedDataCalled,
            "latestBlocksDataProvider.updateScannedData() is expected to be called."
        )
        XCTAssertTrue(
            latestBlocksDataProviderMock.updateBlockDataCalled,
            "latestBlocksDataProvider.updateBlockData() is expected to be called."
        )
        XCTAssertTrue(
            latestBlocksDataProviderMock.updateUnenhancedDataCalled,
            "latestBlocksDataProvider.updateUnenhancedData() is expected to be called."
        )
    }

    private func checkActionContext(_ actionContext: ActionContext, expectedNextState: CBPState) {
        guard let nextContextMock = actionContext as? ActionContextMock else {
            return XCTFail("Result of run(with:) is expected to be an ActionContextMock")
        }
        
        XCTAssertTrue(nextContextMock.updateStateCallsCount == 1)
        XCTAssertTrue(nextContextMock.updateStateReceivedState == expectedNextState)
        
        XCTAssertTrue(
            nextContextMock.updateLastScannedHeightCallsCount == 1,
            "actionContext.update(lastScannedHeight:) is expected to be called."
        )
        XCTAssertTrue(
            nextContextMock.updateLastDownloadedHeightCallsCount == 1,
            "actionContext.update(lastDownloadedHeight:) is expected to be called."
        )
        XCTAssertTrue(
            nextContextMock.updateSyncControlDataCallsCount == 1,
            "actionContext.update(syncControlData:) is expected to be called."
        )
        XCTAssertTrue(
            nextContextMock.updateTotalProgressRangeCallsCount == 1,
            "actionContext.update(totalProgressRange:) is expected to be called."
        )
    }
}
