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
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    var dbData: URL! = nil
    var paramDestination: URL! = nil
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var seedData = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbData = try __dataDbURL()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
        paramDestination = try __documentsDirectory().appendingPathComponent("parameters")
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        if testFileManager.fileExists(atPath: dbData.absoluteString) {
            try testFileManager.trashItem(at: dbData, resultingItemURL: nil)
        }
        try? self.testFileManager.removeItem(at: self.testTempDirectory)
    }
    
    func testWalletInitialization() throws {
        let derivationTool = DerivationTool(networkType: network.networkType)
        let ufvk = try derivationTool.deriveUnifiedSpendingKey(seed: seedData.bytes, accountIndex: 0)
            .map({ try derivationTool.deriveUnifiedFullViewingKey(from: $0) })

        let wallet = Initializer(
            fsBlockDbRoot: self.testTempDirectory,
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
            guard case .success = try synchronizer.prepare(with: seedData.bytes, viewingKeys: [ufvk], walletBirthday: 663194) else {
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
