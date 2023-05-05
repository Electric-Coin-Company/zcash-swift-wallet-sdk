//
//  ZcashTransactionStateTests.swift
//  
//
//  Created by Francisco Gindre on 5/3/23.
//

import XCTest
import TestUtils
@testable import ZcashLightClientKit

final class ZcashTransactionStateTests: XCTestCase {
    func testExpiredUnminedState() throws {
        let currentHeight = 1010

        XCTAssertEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: nil,
                expiredUnmined: true
            ),
            .expired
        )
    }

    func testConfirmationsBelowStaleConstantIsPending() {
        let currentHeight = 1010

        XCTAssertEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight,
                expiredUnmined: false
            ),
            .pending
        )

        XCTAssertEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight - ZcashSDK.defaultStaleTolerance + 1,
                expiredUnmined: false
            ),
            .pending
        )

        XCTAssertNotEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight - ZcashSDK.defaultStaleTolerance,
                expiredUnmined: false
            ),
            .pending
        )
    }

    func testMinedHeightAboveOrEqualToStaleConstantIsConfirmed() {
        let currentHeight = 1010

        XCTAssertEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight - ZcashSDK.defaultStaleTolerance,
                expiredUnmined: false
            ),
            .confirmed
        )

        XCTAssertEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight - ZcashSDK.defaultStaleTolerance - 1,
                expiredUnmined: false
            ),
            .confirmed
        )

        XCTAssertNotEqual(
            ZcashTransaction.Overview.State(
                currentHeight: currentHeight,
                minedHeight: currentHeight - ZcashSDK.defaultStaleTolerance + 1,
                expiredUnmined: false
            ),
            .confirmed
        )
    }
}
