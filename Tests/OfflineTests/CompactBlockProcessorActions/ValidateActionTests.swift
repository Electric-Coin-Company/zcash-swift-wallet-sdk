//
//  ValidateActionTests.swift
//  
//
//  Created by Lukáš Korba on 17.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ValidateActionTests: ZcashTestCase {
    func testValidateAction_NextAction() async throws {
        let blockValidatorMock = BlockValidatorMock()
        
        blockValidatorMock.validateClosure = { }
        
        mockContainer.mock(type: BlockValidator.self, isSingleton: true) { _ in blockValidatorMock }

        let validateAction = ValidateAction(
            container: mockContainer
        )
        
        do {
            let nextContext = try await validateAction.run(with: .init(state: .validate)) { _ in }
            XCTAssertTrue(blockValidatorMock.validateCalled, "validator.validate() is expected to be called.")
            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .scan,
                "nextContext after .validate is expected to be .scan but received \(nextState)"
            )
        } catch {
            XCTFail("testValidateAction_NextAction is not expected to fail. \(error)")
        }
    }
}
