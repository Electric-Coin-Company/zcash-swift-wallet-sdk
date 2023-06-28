//
//  ScanActionTests.swift
//  
//
//  Created by Lukáš Korba on 18.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ScanActionTests: ZcashTestCase {
    func testScanAction_NextAction() async throws {
        let blockScannerMock = BlockScannerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let loggerMock = LoggerMock()
        
        transactionRepositoryMock.lastScannedHeightReturnValue = 1500
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }
        blockScannerMock.scanBlocksAtTotalProgressRangeDidScanClosure = { _, _, _ in 2 }

        let scanAction = setupAction(blockScannerMock, transactionRepositoryMock, loggerMock)
        let syncContext = await setupActionContext()
        
        do {
            let nextContext = try await scanAction.run(with: syncContext) { event in
                guard case .progressPartialUpdate(.syncing(let progress)) = event else {
                    XCTFail("event is expected to be .progressPartialUpdate(.syncing()) but received \(event)")
                    return
                }
                XCTAssertEqual(progress.startHeight, BlockHeight(1000))
                XCTAssertEqual(progress.targetHeight, BlockHeight(2000))
                XCTAssertEqual(progress.progressHeight, BlockHeight(1500))
            }
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(loggerMock.debugFileFunctionLineCalled, "logger.debug(...) is expected to be called.")
            XCTAssertTrue(blockScannerMock.scanBlocksAtTotalProgressRangeDidScanCalled, "blockScanner.scanBlocks(...) is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .clearAlreadyScannedBlocks,
                "nextContext after .scan is expected to be .clearAlreadyScannedBlocks but received \(nextState)"
            )
        } catch {
            XCTFail("testScanAction_NextAction is not expected to fail. \(error)")
        }
    }
    
    func testScanAction_EarlyOutForNoDownloadAndScanRangeSet() async throws {
        let blockScannerMock = BlockScannerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let loggerMock = LoggerMock()
                
        let scanAction = setupAction(blockScannerMock, transactionRepositoryMock, loggerMock)
        let syncContext: ActionContext = .init(state: .scan)
        
        do {
            _ = try await scanAction.run(with: syncContext) { _ in }
            XCTAssertFalse(
                transactionRepositoryMock.lastScannedHeightCalled,
                "transactionRepository.lastScannedHeight() is not expected to be called."
            )
            XCTAssertFalse(loggerMock.debugFileFunctionLineCalled, "logger.debug(...) is not expected to be called.")
            XCTAssertFalse(blockScannerMock.scanBlocksAtTotalProgressRangeDidScanCalled, "blockScanner.scanBlocks(...) is not expected to be called.")
        } catch {
            XCTFail("testScanAction_EarlyOutForNoDownloadAndScanRangeSet is not expected to fail. \(error)")
        }
    }
    
    func testScanAction_StartRangeHigherThanEndRange() async throws {
        let blockScannerMock = BlockScannerMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let loggerMock = LoggerMock()
                
        transactionRepositoryMock.lastScannedHeightReturnValue = 2001

        let scanAction = setupAction(blockScannerMock, transactionRepositoryMock, loggerMock)
        let syncContext = await setupActionContext()
        
        do {
            _ = try await scanAction.run(with: syncContext) { _ in }
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertFalse(loggerMock.debugFileFunctionLineCalled, "logger.debug(...) is not expected to be called.")
            XCTAssertFalse(blockScannerMock.scanBlocksAtTotalProgressRangeDidScanCalled, "blockScanner.scanBlocks(...) is not expected to be called.")
        } catch {
            XCTFail("testScanAction_StartRangeHigherThanEndRange is not expected to fail. \(error)")
        }
    }
    
    private func setupAction(
        _ blockScannerMock: BlockScannerMock,
        _ transactionRepositoryMock: TransactionRepositoryMock,
        _ loggerMock: LoggerMock
    ) -> ScanAction {
        mockContainer.mock(type: BlockScanner.self, isSingleton: true) { _ in blockScannerMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        return ScanAction(
            container: mockContainer,
            configProvider: CompactBlockProcessor.ConfigProvider(config: config)
        )
    }
    
    private func setupActionContext() async -> ActionContext {
        let syncContext: ActionContext = .init(state: .scan)
        
        let syncControlData = SyncControlData(
            latestBlockHeight: 2000,
            latestScannedHeight: 1000,
            firstUnenhancedHeight: nil
        )
        
        await syncContext.update(syncControlData: syncControlData)
        await syncContext.update(totalProgressRange: CompactBlockRange(uncheckedBounds: (1000, 2000)))

        return syncContext
    }
}
