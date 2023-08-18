//
//  ActionContextStateTests.swift
//  
//
//  Created by Lukáš Korba on 15.06.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class ActionContextStateTests: XCTestCase {
    func testPreviousState() async throws {
        let syncContext = ActionContextImpl(state: .idle)
        
        await syncContext.update(state: .clearCache)
        
        let currentState = await syncContext.state
        let prevState = await syncContext.prevState

        XCTAssertTrue(
            currentState == .clearCache,
            "syncContext.state after update is expected to be .clearCache but received \(currentState)"
        )

        if let prevState {
            XCTAssertTrue(
                prevState == .idle,
                "syncContext.prevState after update is expected to be .idle but received \(prevState)"
            )
        } else {
            XCTFail("syncContext.prevState is not expected to be nil.")
        }
    }
    
    func testDefaultSyncAlgorith() async throws {
        let syncContext = ActionContextImpl(state: .idle)
        
        let preferredSyncAlgorithm = await syncContext.preferredSyncAlgorithm
        
        XCTAssertTrue(
            preferredSyncAlgorithm == .linear,
            "ActionContext default preferredSyncAlgorithm is expected to be .linear but received \(preferredSyncAlgorithm)"
        )
    }
}
