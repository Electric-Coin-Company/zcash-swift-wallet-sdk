//
//  WalletTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class WalletTests: XCTestCase {
    let testFileManager = FileManager()

    var dbData: URL! = nil
    var paramDestination: URL! = nil
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var seedData = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbData = try __dataDbURL()
        try self.testFileManager.createDirectory(at: Environment.testTempDirectory, withIntermediateDirectories: false)
        paramDestination = try __documentsDirectory().appendingPathComponent("parameters")
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        if testFileManager.fileExists(atPath: dbData.absoluteString) {
            try testFileManager.trashItem(at: dbData, resultingItemURL: nil)
        }
        try? self.testFileManager.removeItem(at: Environment.testTempDirectory)
    }
    
    func testWalletInitialization() async throws {
        let derivationTool = TestsData(networkType: network.networkType).derivationTools
        let spendingKey = try await derivationTool.deriveUnifiedSpendingKey(seed: seedData.bytes, accountIndex: 0)
        let viewingKey = try await derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

        let wallet = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: Environment.testTempDirectory,
            dataDbURL: try __dataDbURL(),
            pendingDbURL: try TestDbBuilder.pendingTransactionsDbURL(),
            endpoint: LightWalletEndpointBuilder.default,
            network: network,
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests
        )
        
        let synchronizer = SDKSynchronizer(initializer: wallet)
        do {
            guard case .success = try await synchronizer.prepare(with: seedData.bytes, viewingKeys: [viewingKey], walletBirthday: 663194) else {
                XCTFail("Failed to initDataDb. Expected `.success` got: `.seedRequired`")
                return
            }
        } catch {
            XCTFail("shouldn't fail here. Got error: \(error)")
        }

        // fileExists actually sucks, so attempting to delete the file and checking what happens is far better :)
        XCTAssertNoThrow( try FileManager.default.removeItem(at: dbData!) )
    }
}
