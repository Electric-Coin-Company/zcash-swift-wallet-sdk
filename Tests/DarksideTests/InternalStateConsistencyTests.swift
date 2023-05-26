//
//  InternalStateConsistencyTests.swift
//  DarksideTests
//
//  Created by Francisco Gindre on 1/26/23.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class InternalStateConsistencyTests: ZcashTestCase {
    let sendAmount = Zatoshi(1000)
    var birthday: BlockHeight = 663150
    let defaultLatestHeight: BlockHeight = 663175
    var coordinator: TestCoordinator!
    var firstSyncExpectation = XCTestExpectation(description: "first sync expectation")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188
    var reorgExpectation = XCTestExpectation(description: "reorg")
    let branchID = "2bb40e60"
    let chainName = "main"
    let network = DarksideWalletDNetwork()
    var sdkSynchronizerInternalSyncStatusHandler: SDKSynchronizerInternalSyncStatusHandler! = SDKSynchronizerInternalSyncStatusHandler()

    override func setUp() async throws {
        try await super.setUp()

        // don't use an exact birthday, users never do.
        self.coordinator = try await TestCoordinator(
            container: mockContainer,
            walletBirthday: birthday + 50,
            network: network
        )

        try await coordinator.reset(saplingActivation: 663150, branchID: self.branchID, chainName: self.chainName)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        let coordinator = self.coordinator!
        self.coordinator = nil
        sdkSynchronizerInternalSyncStatusHandler = nil

        try await coordinator.stop()
        try? FileManager.default.removeItem(at: coordinator.databases.fsCacheDbRoot)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
    }

    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
