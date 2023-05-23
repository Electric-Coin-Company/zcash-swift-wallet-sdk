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

        loggerMock.debugFileFunctionLineClosure = { _, _, _, _ in }
        saplingParametersHandlerMock.handleIfNeededClosure = { }

        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        mockContainer.mock(type: SaplingParametersHandler.self, isSingleton: true) { _ in saplingParametersHandlerMock }

        let saplingParamsActionAction = SaplingParamsAction(container: mockContainer)
        
        do {
            let nextContext = try await saplingParamsActionAction.run(with: .init(state: .handleSaplingParams)) { _ in }
            XCTAssertTrue(loggerMock.debugFileFunctionLineCalled, "logger.debug(...) is expected to be called.")
            XCTAssertTrue(saplingParametersHandlerMock.handleIfNeededCalled, "saplingParametersHandler.handleIfNeeded() is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .download,
                "nextContext after .handleSaplingParams is expected to be .download but received \(nextState)"
            )
        } catch {
            XCTFail("testSaplingParamsAction_NextAction is not expected to fail. \(error)")
        }
    }
}
