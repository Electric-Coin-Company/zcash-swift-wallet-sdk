//
//  DownloadActionTests.swift
//  
//
//  Created by Lukáš Korba on 21.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class DownloadActionTests: ZcashTestCase {
    var underlyingDownloadRange: CompactBlockRange?
    var underlyingScanRange: CompactBlockRange?

    func testDownloadAction_NextAction() async throws {
        let blockDownloaderMock = BlockDownloaderMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1
        blockDownloaderMock.setSyncRangeBatchSizeClosure = { _, _ in }
        blockDownloaderMock.setDownloadLimitClosure = { _ in }
        blockDownloaderMock.startDownloadMaxBlockBufferSizeClosure = { _ in }
        blockDownloaderMock.waitUntilRequestedBlocksAreDownloadedInClosure = { _ in }

        let downloadAction = setupAction(
            blockDownloaderMock,
            transactionRepositoryMock
        )
        
        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await downloadAction.run(with: syncContext) { _ in }

            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(blockDownloaderMock.setSyncRangeBatchSizeCalled, "downloader.setSyncRange() is expected to be called.")
            XCTAssertTrue(blockDownloaderMock.setDownloadLimitCalled, "downloader.setDownloadLimit() is expected to be called.")
            XCTAssertTrue(blockDownloaderMock.startDownloadMaxBlockBufferSizeCalled, "downloader.startDownload() is expected to be called.")
            XCTAssertTrue(
                blockDownloaderMock.waitUntilRequestedBlocksAreDownloadedInCalled,
                "downloader.waitUntilRequestedBlocksAreDownloaded() is expected to be called."
            )

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validate,
                "nextContext after .download is expected to be .validate but received \(nextState)"
            )
        } catch {
            XCTFail("testDownloadAction_NextAction is not expected to fail. \(error)")
        }
    }
    
    func testDownloadAction_NoDownloadAndScanRange() async throws {
        let blockDownloaderMock = BlockDownloaderMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        
        let downloadAction = setupAction(
            blockDownloaderMock,
            transactionRepositoryMock
        )
        
        let syncContext = await setupActionContext()

        do {
            let nextContext = try await downloadAction.run(with: syncContext) { _ in }

            XCTAssertFalse(
                transactionRepositoryMock.lastScannedHeightCalled,
                "transactionRepository.lastScannedHeight() is not expected to be called."
            )
            XCTAssertFalse(blockDownloaderMock.setSyncRangeBatchSizeCalled, "downloader.setSyncRange() is not expected to be called.")
            XCTAssertFalse(blockDownloaderMock.setDownloadLimitCalled, "downloader.setDownloadLimit() is not expected to be called.")
            XCTAssertFalse(blockDownloaderMock.startDownloadMaxBlockBufferSizeCalled, "downloader.startDownload() is not expected to be called.")
            XCTAssertFalse(
                blockDownloaderMock.waitUntilRequestedBlocksAreDownloadedInCalled,
                "downloader.waitUntilRequestedBlocksAreDownloaded() is not expected to be called."
            )
            
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validate,
                "nextContext after .download is expected to be .validate but received \(nextState)"
            )
        } catch {
            XCTFail("testDownloadAction_NoDownloadAndScanRange is not expected to fail. \(error)")
        }
    }
    
    func testDownloadAction_NothingMoreToDownload() async throws {
        let blockDownloaderMock = BlockDownloaderMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 2001

        let downloadAction = setupAction(
            blockDownloaderMock,
            transactionRepositoryMock
        )
        
        underlyingDownloadRange = CompactBlockRange(uncheckedBounds: (1000, 2000))
        underlyingScanRange = CompactBlockRange(uncheckedBounds: (1000, 2000))

        let syncContext = await setupActionContext()

        do {
            let nextContext = try await downloadAction.run(with: syncContext) { _ in }

            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertFalse(blockDownloaderMock.setSyncRangeBatchSizeCalled, "downloader.setSyncRange() is not expected to be called.")
            XCTAssertFalse(blockDownloaderMock.setDownloadLimitCalled, "downloader.setDownloadLimit() is not expected to be called.")
            XCTAssertFalse(blockDownloaderMock.startDownloadMaxBlockBufferSizeCalled, "downloader.startDownload() is not expected to be called.")
            XCTAssertFalse(
                blockDownloaderMock.waitUntilRequestedBlocksAreDownloadedInCalled,
                "downloader.waitUntilRequestedBlocksAreDownloaded() is not expected to be called."
            )
            
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validate,
                "nextContext after .download is expected to be .validate but received \(nextState)"
            )
        } catch {
            XCTFail("testDownloadAction_NoDownloadAndScanRange is not expected to fail. \(error)")
        }
    }
    
    func testDownloadAction_DownloadStops() async throws {
        let blockDownloaderMock = BlockDownloaderMock()

        blockDownloaderMock.stopDownloadClosure = { }
        
        let downloadAction = setupAction(
            blockDownloaderMock
        )

        await downloadAction.stop()
        
        XCTAssertTrue(blockDownloaderMock.stopDownloadCalled, "downloader.stopDownload() is expected to be called.")
    }

    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .download)

        let syncRanges = SyncRanges(
            latestBlockHeight: 0,
            downloadRange: underlyingDownloadRange,
            scanRange: underlyingScanRange,
            enhanceRange: nil,
            fetchUTXORange: nil,
            latestScannedHeight: nil,
            latestDownloadedBlockHeight: nil
        )
        
        await syncContext.update(syncRanges: syncRanges)

        return syncContext
    }
    
    private func setupAction(
        _ blockDownloaderMock: BlockDownloaderMock = BlockDownloaderMock(),
        _ transactionRepositoryMock: TransactionRepositoryMock = TransactionRepositoryMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> DownloadAction {
        mockContainer.mock(type: BlockDownloader.self, isSingleton: true) { _ in blockDownloaderMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }

        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return DownloadAction(
            container: mockContainer,
            config: config
        )
    }
}
