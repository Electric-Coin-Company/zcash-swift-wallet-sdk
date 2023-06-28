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

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncControlDataAction.run(with: syncContext) { _ in }

            XCTAssertTrue(
                latestBlocksDataProviderMock.updateScannedDataCalled,
                "latestBlocksDataProvider.updateScannedData() is expected to be called."
            )
            XCTAssertTrue(
                latestBlocksDataProviderMock.updateBlockDataCalled,
                "latestBlocksDataProvider.updateBlockData() is expected to be called."
            )

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .finished,
                "nextContext after .computeSyncControlData is expected to be .finished but received \(nextState)"
            )
        } catch {
            XCTFail("testComputeSyncControlDataAction_finishProcessingCase is not expected to fail. \(error)")
        }
    }
    
    func testComputeSyncControlDataAction_fetchUTXOsCase() async throws {
        let blockDownloaderServiceMock = BlockDownloaderServiceMock()
        let latestBlocksDataProviderMock = LatestBlocksDataProviderMock()
        let loggerMock = LoggerMock()
        
        let computeSyncControlDataAction = setupDefaultMocksAndReturnAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            loggerMock
        )
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 10

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await computeSyncControlDataAction.run(with: syncContext) { _ in }

            XCTAssertTrue(
                latestBlocksDataProviderMock.updateScannedDataCalled,
                "latestBlocksDataProvider.updateScannedData() is expected to be called."
            )
            XCTAssertTrue(latestBlocksDataProviderMock.updateBlockDataCalled, "latestBlocksDataProvider.updateBlockData() is expected to be called.")
            XCTAssertFalse(loggerMock.infoFileFunctionLineCalled, "logger.info() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .fetchUTXO,
                "nextContext after .computeSyncControlData is expected to be .fetchUTXO but received \(nextState)"
            )
        } catch {
            XCTFail("testComputeSyncControlDataAction_checksBeforeSyncCase is not expected to fail. \(error)")
        }
    }
    
    private func setupSyncControlData() -> SyncControlData {
        SyncControlData(
            latestBlockHeight: 0,
            latestScannedHeight: underlyingScanRange?.lowerBound,
            firstUnenhancedHeight: nil
        )
    }
    
    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .computeSyncControlData)
        
        await syncContext.update(syncControlData: setupSyncControlData())
        await syncContext.update(totalProgressRange: CompactBlockRange(uncheckedBounds: (1000, 2000)))

        return syncContext
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
    
    private func setupDefaultMocksAndReturnAction(
        _ blockDownloaderServiceMock: BlockDownloaderServiceMock = BlockDownloaderServiceMock(),
        _ latestBlocksDataProviderMock: LatestBlocksDataProviderMock = LatestBlocksDataProviderMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> ComputeSyncControlDataAction {
        blockDownloaderServiceMock.lastDownloadedBlockHeightReturnValue = 1
        latestBlocksDataProviderMock.underlyingLatestBlockHeight = 1
        latestBlocksDataProviderMock.underlyingLatestScannedHeight = 1
        latestBlocksDataProviderMock.updateScannedDataClosure = { }
        latestBlocksDataProviderMock.updateBlockDataClosure = { }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }
        
        return setupAction(
            blockDownloaderServiceMock,
            latestBlocksDataProviderMock,
            loggerMock
        )
    }
}
