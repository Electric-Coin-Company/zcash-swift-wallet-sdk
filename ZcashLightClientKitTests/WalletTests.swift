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
        
        dbData = try! __dataDbURL()
        cacheData = try! __cacheDbURL()
        paramDestination = try! __documentsDirectory().appendingPathComponent("parameters")
    }
    
    override func tearDown() {
        if FileManager.default.fileExists(atPath: dbData.absoluteString) {
           try! FileManager.default.trashItem(at: dbData, resultingItemURL: nil)
        }
    }
    
    func testWalletInitialization() {
        
        let wallet = Initializer(cacheDbURL: cacheData, dataDbURL: dbData, endpoint: LightWalletEndpoint(address: "localhost", port: "9067", secure: false))
        
        XCTAssertNoThrow(try wallet.initialize(seedProvider: SampleSeedProvider(), walletBirthdayHeight: SAPLING_ACTIVATION_HEIGHT))
        
        // fileExists actually sucks, so attempting to delete the file and checking what happens is far better :)
        XCTAssertNoThrow( try FileManager.default.removeItem(at: dbData!) )
        // TODO: Initialize cacheDB on start, will be done when Synchronizer is ready and integrated 
//        XCTAssertNoThrow( try FileManager.default.removeItem(at: cacheData!) )
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
