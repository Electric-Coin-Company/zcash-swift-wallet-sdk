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

// swiftlint:disable implicitly_unwrapped_optional force_try force_unwrapping
class WalletTests: XCTestCase {
    var dbData: URL! = nil
    var paramDestination: URL! = nil
    var cacheData: URL! = nil
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var seedData = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!

    override func setUp() {
        super.setUp()
        dbData = try! __dataDbURL()
        cacheData = try! __cacheDbURL()
        paramDestination = try! __documentsDirectory().appendingPathComponent("parameters")
    }
    
    override func tearDown() {
        super.tearDown()
        if FileManager.default.fileExists(atPath: dbData.absoluteString) {
            try! FileManager.default.trashItem(at: dbData, resultingItemURL: nil)
        }
    }
    
    func testWalletInitialization() throws {
        let derivationTool = DerivationTool(networkType: network.networkType)
        let ufvk = try derivationTool.deriveUnifiedSpendingKey(seed: seedData.bytes, accountIndex: 0)
            .map( { try derivationTool.deriveUnifiedFullViewingKey(from: $0) })
        let wallet = Initializer(
            cacheDbURL: try __cacheDbURL(),
            dataDbURL: try __dataDbURL(),
            pendingDbURL: try TestDbBuilder.pendingTransactionsDbURL(),
            endpoint: LightWalletEndpointBuilder.default,
            network: network,
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            viewingKeys: [ufvk],
            walletBirthday: 663194
        )
        
        let synchronizer = try SDKSynchronizer(initializer: wallet)
        do {
            guard case .success = try synchronizer.prepare(with: seedData.bytes) else {
                XCTFail("Failed to initDataDb. Expected `.success` got: `.seedRequired`")
                return
            }
        } catch {
            XCTFail("shouldn't fail here")
        }
        
        // fileExists actually sucks, so attempting to delete the file and checking what happens is far better :)
        XCTAssertNoThrow( try FileManager.default.removeItem(at: dbData!) )
        // TODO: Initialize cacheDB on start, will be done when Synchronizer is ready and integrated
//        XCTAssertNoThrow( try FileManager.default.removeItem(at: cacheData!) )
    }
}
