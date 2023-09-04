//
//  UpdateChainTipActionTests.swift
//  
//
//  Created by Lukáš Korba on 25.08.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class UpdateChainTipActionTests: ZcashTestCase {
    var underlyingChainName = ""
    var underlyingNetworkType = NetworkType.testnet
    var underlyingSaplingActivationHeight: BlockHeight?
    var underlyingConsensusBranchID = ""

    override func setUp() {
        super.setUp()
        
        underlyingChainName = "test"
        underlyingNetworkType = .testnet
        underlyingSaplingActivationHeight = nil
        underlyingConsensusBranchID = "c2d6d0b4"
    }

    func testUpdateChainTipAction_UpdateChainTipTimeTriggered() async throws {
        let loggerMock = LoggerMock()
        let blockDownloaderMock = BlockDownloaderMock()

        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        blockDownloaderMock.stopDownloadClosure = { }

        let updateChainTipAction = await setupAction(loggerMock, blockDownloaderMock)

        do {
            let context = ActionContextMock.default()
            context.prevState = .idle
            context.underlyingLastChainTipUpdateTime = 0.0
            context.updateLastChainTipUpdateTimeClosure = { _ in }

            let nextContext = try await updateChainTipAction.run(with: context) { _ in }
            
            XCTAssertTrue(blockDownloaderMock.stopDownloadCallsCount == 1, "downloader.stopDownload() is expected to be called exactly once.")

            let acResult = nextContext.checkStateIs(.clearCache)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testUpdateChainTipAction_UpdateChainTipTimeTriggered is not expected to fail. \(error)")
        }
    }
    
    func testUpdateChainTipAction_UpdateChainTipPrevActionTriggered() async throws {
        let loggerMock = LoggerMock()
        let blockDownloaderMock = BlockDownloaderMock()

        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        blockDownloaderMock.stopDownloadClosure = { }

        let updateChainTipAction = await setupAction(loggerMock, blockDownloaderMock)

        do {
            let context = ActionContextMock.default()
            context.prevState = .updateSubtreeRoots
            context.underlyingLastChainTipUpdateTime = Date().timeIntervalSince1970
            context.updateLastChainTipUpdateTimeClosure = { _ in }

            let nextContext = try await updateChainTipAction.run(with: context) { _ in }
            
            XCTAssertTrue(blockDownloaderMock.stopDownloadCallsCount == 1, "downloader.stopDownload() is expected to be called exactly once.")

            let acResult = nextContext.checkStateIs(.clearCache)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testUpdateChainTipAction_UpdateChainTipPrevActionTriggered is not expected to fail. \(error)")
        }
    }
    
    func testUpdateChainTipAction_UpdateChainTipSkipped() async throws {
        let loggerMock = LoggerMock()
        let blockDownloaderMock = BlockDownloaderMock()

        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        blockDownloaderMock.stopDownloadClosure = { }

        let updateChainTipAction = await setupAction(loggerMock, blockDownloaderMock)

        do {
            let context = ActionContextMock.default()
            context.prevState = .enhance
            context.underlyingLastChainTipUpdateTime = Date().timeIntervalSince1970
            context.updateLastChainTipUpdateTimeClosure = { _ in }

            let nextContext = try await updateChainTipAction.run(with: context) { _ in }
            
            XCTAssertFalse(blockDownloaderMock.stopDownloadCalled, "downloader.stopDownload() is not expected to be called.")
            
            let acResult = nextContext.checkStateIs(.download)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testUpdateChainTipAction_UpdateChainTipSkipped is not expected to fail. \(error)")
        }
    }
    
    private func setupAction(
        _ loggerMock: LoggerMock = LoggerMock(),
        _ blockDownloaderMock: BlockDownloaderMock = BlockDownloaderMock()
    ) async -> UpdateChainTipAction {
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: underlyingNetworkType), walletBirthday: 0
        )

        let rustBackendMock = ZcashRustBackendWeldingMock(
            consensusBranchIdForHeightClosure: { height in
                XCTAssertEqual(height, 2, "")
                return -1026109260
            }
        )
        
        await rustBackendMock.setUpdateChainTipHeightClosure( { _ in } )
        
        let lightWalletdInfoMock = LightWalletdInfoMock()
        lightWalletdInfoMock.underlyingConsensusBranchID = underlyingConsensusBranchID
        lightWalletdInfoMock.underlyingSaplingActivationHeight = UInt64(underlyingSaplingActivationHeight ?? config.saplingActivation)
        lightWalletdInfoMock.underlyingBlockHeight = 2
        lightWalletdInfoMock.underlyingChainName = underlyingChainName

        let serviceMock = LightWalletServiceMock()
        serviceMock.getInfoReturnValue = lightWalletdInfoMock
        serviceMock.latestBlockHeightReturnValue = 1
        
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in rustBackendMock }
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in serviceMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        mockContainer.mock(type: BlockDownloader.self, isSingleton: true) { _ in blockDownloaderMock }

        return UpdateChainTipAction(container: mockContainer)
    }
}
