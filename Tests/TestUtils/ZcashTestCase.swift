//
//  ZcashTestCase.swift
//  
//
//  Created by Michal Fousek on 01.05.2023.
//

import Foundation
@testable import ZcashLightClientKit
import XCTest

class ZcashTestCase: XCTestCase {
    var mockContainer: DIContainer!

    private func createMockContainer() {
        guard mockContainer == nil else { return }
        mockContainer = DIContainer()
        mockContainer.isTestEnvironment = true
    }

    private func destroyMockContainer() {
        mockContainer = nil
    }

    override func setUp() async throws {
        try await super.setUp()
        createMockContainer()
    }

    override func setUp() {
        super.setUp()
        createMockContainer()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        createMockContainer()
    }

    override func tearDown() {
        super.tearDown()
        destroyMockContainer()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        destroyMockContainer()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        destroyMockContainer()
    }
}
