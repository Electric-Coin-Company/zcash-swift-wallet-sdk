//
//  ErrorLocalizationTests.swift
//  
//
//  Created by Francisco Gindre on 7/11/22.
//

import XCTest
import ZcashLightClientKit
class ErrorLocalizationTests: XCTestCase {

    func testLocalizedError() throws {
        let sychronizerError = SynchronizerError.networkTimeout as Error
        XCTAssertEqual(sychronizerError.localizedDescription, "Network Timeout. Please check Internet connection")
    }

}
