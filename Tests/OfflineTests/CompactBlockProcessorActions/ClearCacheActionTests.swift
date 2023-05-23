//
//  ClearCacheActionTests.swift
//  
//
//  Created by Lukáš Korba on 22.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ClearCacheActionTests: ZcashTestCase {
    func testClearCacheAction_NextAction() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()

        compactBlockRepositoryMock.clearClosure = { }

        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in compactBlockRepositoryMock }

        let clearCacheAction = ClearCacheAction(
            container: mockContainer
        )

        do {
            let nextContext = try await clearCacheAction.run(with: .init(state: .clearCache)) { _ in }
            XCTAssertTrue(compactBlockRepositoryMock.clearCalled, "storage.clear() is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .finished,
                "nextContext after .clearCache is expected to be .finished but received \(nextState)"
            )
        } catch {
            XCTFail("testClearCacheActionTests_NextAction is not expected to fail. \(error)")
        }
    }
}
