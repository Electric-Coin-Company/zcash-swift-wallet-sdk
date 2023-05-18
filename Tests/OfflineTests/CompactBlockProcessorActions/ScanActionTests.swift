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

        mockContainer.mock(type: BlockScanner.self, isSingleton: true) { _ in blockScannerMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }

        let config: CompactBlockProcessor.Configuration = .standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )

        let scanAction = ScanAction(
            container: mockContainer,
            config: config
        )
        
        do {
            let nextContext = try await scanAction.run(with: .init(state: .scan)) { _ in }
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .clearAlreadyScannedBlocks,
                "nextContext after .scan is expected to be .clearAlreadyScannedBlocks but received \(nextState)"
            )
        } catch {
            XCTFail("testScanAction_NextAction is not expected to fail. \(error)")
        }
    }
}
