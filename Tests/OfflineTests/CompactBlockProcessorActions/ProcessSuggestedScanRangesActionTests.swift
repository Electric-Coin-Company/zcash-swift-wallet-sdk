//
//  ProcessSuggestedScanRangesActionTests.swift
//  
//
//  Created by Lukáš Korba on 25.08.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ProcessSuggestedScanRangesActionTests: ZcashTestCase {
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

    func testProcessSuggestedScanRangesAction_EmptyScanRanges() async throws {
        let loggerMock = LoggerMock()
        
        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }

        let tupple = setupAction(loggerMock)
        await tupple.rustBackendMock.setSuggestScanRangesClosure( { [] } )
        
        let processSuggestedScanRangesActionAction = tupple.action

        do {
            let context = ActionContextMock.default()

            let nextContext = try await processSuggestedScanRangesActionAction.run(with: context) { _ in }

            XCTAssertFalse(
                loggerMock.debugFileFunctionLineCalled,
                "logger.debug() is not expected to be called."
            )
            
            let acResult = nextContext.checkStateIs(.finished)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testProcessSuggestedScanRangesAction_EmptyScanRanges is not expected to fail. \(error)")
        }
    }
    
    func testProcessSuggestedScanRangesAction_VerifyScanRangeSetTotalProgressRange() async throws {
        let loggerMock = LoggerMock()
        
        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in  }

        let tupple = setupAction(loggerMock)
        await tupple.rustBackendMock.setSuggestScanRangesClosure( { [
            ScanRange(range: 0..<10, priority: .verify)
        ] } )
        
        let processSuggestedScanRangesActionAction = tupple.action

        do {
            let context = ActionContextMock.default()
            context.updateLastScannedHeightClosure = { _ in }
            context.updateLastDownloadedHeightClosure = { _ in }
            context.updateSyncControlDataClosure = { _ in }
            context.underlyingTotalProgressRange = 0...0
            context.updateTotalProgressRangeClosure = { _ in }
            context.updateRequestedRewindHeightClosure = { _ in }

            let nextContext = try await processSuggestedScanRangesActionAction.run(with: context) { _ in }

            XCTAssertTrue(
                loggerMock.debugFileFunctionLineCalled,
                "logger.debug() is not expected to be called."
            )

            if let nextContextMock = nextContext as? ActionContextMock {
                XCTAssertTrue(
                    nextContextMock.updateRequestedRewindHeightCallsCount == 1,
                    "context.update(requestedRewindHeight:) is expected to be called exactly once."
                )
            } else {
                XCTFail("`nextContext` is not the ActionContextMock")
            }

            XCTAssertTrue(
                loggerMock.debugFileFunctionLineCalled,
                "logger.debug() is not expected to be called."
            )

            if let infoArguments = loggerMock.infoFileFunctionLineReceivedArguments {
                XCTAssertTrue(infoArguments.message.contains("Setting the total range for Spend before Sync to"))
            } else {
                XCTFail("`infoArguments` unavailable.")
            }
            
            let acResult = nextContext.checkStateIs(.rewind)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testProcessSuggestedScanRangesAction_VerifyScanRangeSetTotalProgressRange is not expected to fail. \(error)")
        }
    }
    
    func testProcessSuggestedScanRangesAction_VerifyScanRangeTotalProgressRangeSkipped() async throws {
        let loggerMock = LoggerMock()
        
        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in  }

        let tupple = setupAction(loggerMock)
        await tupple.rustBackendMock.setSuggestScanRangesClosure( { [
            ScanRange(range: 0..<10, priority: .verify)
        ] } )
        
        let processSuggestedScanRangesActionAction = tupple.action

        do {
            let context = ActionContextMock.default()
            context.updateLastScannedHeightClosure = { _ in }
            context.updateLastDownloadedHeightClosure = { _ in }
            context.updateSyncControlDataClosure = { _ in }
            context.underlyingTotalProgressRange = 1...1
            context.updateRequestedRewindHeightClosure = { _ in }

            let nextContext = try await processSuggestedScanRangesActionAction.run(with: context) { _ in }

            XCTAssertTrue(
                loggerMock.debugFileFunctionLineCalled,
                "logger.debug() is not expected to be called."
            )
            
            if let nextContextMock = nextContext as? ActionContextMock {
                XCTAssertTrue(
                    nextContextMock.updateRequestedRewindHeightCallsCount == 1,
                    "context.update(requestedRewindHeight:) is expected to be called exactly once."
                )
            } else {
                XCTFail("`nextContext` is not the ActionContextMock")
            }

            if let infoArguments = loggerMock.infoFileFunctionLineReceivedArguments {
                XCTAssertFalse(infoArguments.message.contains("Setting the total range for Spend before Sync to"))
            } else {
                XCTFail("`infoArguments` unavailable.")
            }
            
            let acResult = nextContext.checkStateIs(.rewind)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testProcessSuggestedScanRangesAction_VerifyScanRangeTotalProgressRangeSkipped is not expected to fail. \(error)")
        }
    }
    
    func testProcessSuggestedScanRangesAction_ChainTipScanRange() async throws {
        let loggerMock = LoggerMock()
        
        loggerMock.infoFileFunctionLineClosure = { _, _, _, _ in  }
        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in  }

        let tupple = setupAction(loggerMock)
        await tupple.rustBackendMock.setSuggestScanRangesClosure( { [
            ScanRange(range: 0..<10, priority: .chainTip)
        ] } )
        
        let processSuggestedScanRangesActionAction = tupple.action

        do {
            let context = ActionContextMock.default()
            context.updateLastScannedHeightClosure = { _ in }
            context.updateLastDownloadedHeightClosure = { _ in }
            context.updateSyncControlDataClosure = { _ in }
            context.underlyingTotalProgressRange = 1...1
            context.updateRequestedRewindHeightClosure = { _ in }

            let nextContext = try await processSuggestedScanRangesActionAction.run(with: context) { _ in }

            if let nextContextMock = nextContext as? ActionContextMock {
                XCTAssertFalse(
                    nextContextMock.updateRequestedRewindHeightCalled,
                    "context.update(requestedRewindHeight:) is not expected to be called"
                )
            } else {
                XCTFail("`nextContext` is not the ActionContextMock")
            }

            XCTAssertTrue(
                loggerMock.debugFileFunctionLineCalled,
                "logger.debug() is not expected to be called."
            )
            
            if let infoArguments = loggerMock.infoFileFunctionLineReceivedArguments {
                XCTAssertFalse(infoArguments.message.contains("Setting the total range for Spend before Sync to"))
            } else {
                XCTFail("`infoArguments` unavailable.")
            }
            
            let acResult = nextContext.checkStateIs(.download)
            XCTAssertTrue(acResult == .true, "Check of state failed with '\(acResult)'")
        } catch {
            XCTFail("testProcessSuggestedScanRangesAction_ChainTipScanRange is not expected to fail. \(error)")
        }
    }
    
    private func setupAction(
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> (
        action: ProcessSuggestedScanRangesAction,
        serviceMock: LightWalletServiceMock,
        rustBackendMock: ZcashRustBackendWeldingMock
    ) {
        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: underlyingNetworkType), walletBirthday: 0
        )

        let rustBackendMock = ZcashRustBackendWeldingMock(
            consensusBranchIdForHeightClosure: { height in
                XCTAssertEqual(height, 2, "")
                return -1026109260
            }
        )
        
        let lightWalletdInfoMock = LightWalletdInfoMock()
        lightWalletdInfoMock.underlyingConsensusBranchID = underlyingConsensusBranchID
        lightWalletdInfoMock.underlyingSaplingActivationHeight = UInt64(underlyingSaplingActivationHeight ?? config.saplingActivation)
        lightWalletdInfoMock.underlyingBlockHeight = 2
        lightWalletdInfoMock.underlyingChainName = underlyingChainName

        let serviceMock = LightWalletServiceMock()
        serviceMock.getInfoReturnValue = lightWalletdInfoMock

        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in rustBackendMock }
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in serviceMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }

        return (
            action:ProcessSuggestedScanRangesAction(container: mockContainer),
            serviceMock: serviceMock,
            rustBackendMock: rustBackendMock
        )
    }
}
