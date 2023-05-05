//
//  ClearAlreadyScannedBlocksActionTests.swift
//  
//
//  Created by Lukáš Korba on 22.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ClearAlreadyScannedBlocksActionTests: ZcashTestCase {
    func testClearAlreadyScannedBlocksAction_NextAction() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()

        compactBlockRepositoryMock.clearUpToClosure = { _ in }
        transactionRepositoryMock.lastScannedHeightReturnValue = 1

        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in compactBlockRepositoryMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }

        let clearAlreadyScannedBlocksAction = ClearAlreadyScannedBlocksAction(
            container: mockContainer
        )

        do {
            let nextContext = try await clearAlreadyScannedBlocksAction.run(with: .init(state: .clearAlreadyScannedBlocks)) { _ in }
            XCTAssertTrue(compactBlockRepositoryMock.clearUpToCalled, "storage.clear(upTo:) is expected to be called.")
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .enhance,
                "nextContext after .clearAlreadyScannedBlocks is expected to be .enhance but received \(nextState)"
            )
        } catch {
            XCTFail("testClearAlreadyScannedBlocksAction_NextAction is not expected to fail. \(error)")
        }
    }
}
