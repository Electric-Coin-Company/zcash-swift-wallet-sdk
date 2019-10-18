//
//  WalletTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import XCTest
@testable import ZcashLightClientKit

class WalletTests: XCTestCase {
    
    var dbData: URL! = nil
    var paramDestination: URL! = nil
    var cacheData: URL! = nil
    
    override func setUp() {
        let dataDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        dbData = dataDir.appendingPathComponent("data.db")
        cacheData = dataDir.appendingPathComponent("cache.db")
        paramDestination = dataDir.appendingPathComponent("parameters")
    }
    
    override func tearDown() {
        if FileManager.default.fileExists(atPath: dbData.absoluteString) {
           try! FileManager.default.trashItem(at: dbData, resultingItemURL: nil)
        }
    }
    
    func testWalletInitialization() {
        
        let wallet = Wallet(rustWelding: ZcashRustBackend.self, cacheDbURL: cacheData, dataDbURL: dbData, paramDestination: paramDestination, seedProvider: SampleSeedProvider(), walletBirthday: WalletBirthdayProvider.testBirthday)
        
        XCTAssertNoThrow(try wallet.initalize())
        
        // fileExists actually sucks, so attempting to delete the file and checking what happens is far better :)
        XCTAssertNoThrow( try FileManager.default.removeItem(at: dbData!) )

        guard let latestBlockHeight = wallet.latestBlockHeight() else {
            XCTFail("should get BlockHeight.empty() from freshly initialized wallet")
            return
        }
        
        XCTAssertEqual(latestBlockHeight, BlockHeight.empty())
        
        XCTAssertNoThrow( try FileManager.default.removeItem(at: cacheData!) )
    }
}

struct SampleSeedProvider: SeedProvider {
    func seed() -> [UInt8] {
        Array("seed".utf8)
    }
}

struct WalletBirthdayProvider {
    static var testBirthday: WalletBirthday {
        WalletBirthday()
    }
}
