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
    
//    func testWalletInitialization() {
//        
//        let wallet = Initializer(cacheDbURL: cacheData,
//                                 dataDbURL: dbData,
//                                 pendingDbURL: try! TestDbBuilder.pendingTransactionsDbURL(),
//                                 endpoint: LightWalletEndpointBuilder.default,
//                                 spendParamsURL: try! __spendParamsURL(),
//                                 outputParamsURL: try! __outputParamsURL()
//                                 )
//        
//        XCTAssertNoThrow(try wallet.initialize(viewingKeys: ["zxviewtestsapling1qwxyzvdmqqqqpqy3knx32fpja779wzg76kmglgguvr74g773f3aw3gy37rar6y9d37knvskz6thnea55s05cz3a7q38835hq4w58yevn763cn2wf7k2mpj247ynxpt9qm0nn39slkz5dk572hxr43pxqtg5kz3pqcj8z8uhz0l2vx8gxe90uf4pgw7ks23f0hz2hm47k9ym42cmns3tenhxzlyur2nvx68h4fmk9nrs44ymcqz434zsuxpvhklrjzn00gc43fdghn5szc5x2w"], walletBirthday: 663194))
//        
//        // fileExists actually sucks, so attempting to delete the file and checking what happens is far better :)
//        XCTAssertNoThrow( try FileManager.default.removeItem(at: dbData!) )
//        // TODO: Initialize cacheDB on start, will be done when Synchronizer is ready and integrated 
////        XCTAssertNoThrow( try FileManager.default.removeItem(at: cacheData!) )
//    }
}

struct WalletBirthdayProvider {
    static var testBirthday: WalletBirthday {
        WalletBirthday()
    }
}
