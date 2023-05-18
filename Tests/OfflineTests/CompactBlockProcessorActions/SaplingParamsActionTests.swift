//
//  SaplingParamsActionTests.swift
//  
//
//  Created by Lukáš Korba on 18.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class SaplingParamsActionTests: ZcashTestCase {
    func testSaplingParamsAction_NextAction() async throws {
        let loggerMock = LoggerMock()
        let saplingParametersHandlerMock = SaplingParametersHandlerMock()

        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        mockContainer.mock(type: SaplingParametersHandler.self, isSingleton: true) { _ in saplingParametersHandlerMock }

        let saplingParamsActionAction = SaplingParamsAction(container: mockContainer)
        
        do {
            let nextContext = try await saplingParamsActionAction.run(with: .init(state: .handleSaplingParams)) { _ in }
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .scanDownloaded,
                "nextContext after .handleSaplingParams is expected to be .scanDownloaded but received \(nextState)"
            )
        } catch {
            XCTFail("testSaplingParamsAction_NextAction is not expected to fail. \(error)")
        }
    }
}
