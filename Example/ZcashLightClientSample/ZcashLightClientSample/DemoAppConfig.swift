//
//  DemoAppConfig.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 10/31/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import ZcashLightClientKit
import MnemonicSwift
struct DemoAppConfig {
    static var host = ZcashSDK.isMainnet ? "localhost" : "lightwalletd.testnet.electriccoin.co"
    static var port: Int = 9067
    static var birthdayHeight: BlockHeight = ZcashSDK.isMainnet ? 663174 : 620_000
    static var network = ZcashSDK.isMainnet ? ZcashNetwork.mainNet : ZcashNetwork.testNet
    static var seed = ZcashSDK.isMainnet ? try! Mnemonic.deterministicSeedBytes(from: "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread") : Array("testreferencealicetestreferencealice".utf8)
    static var address: String {
        "\(host):\(port)"
    }
    
    static var processorConfig: CompactBlockProcessor.Configuration {
        var config = CompactBlockProcessor.Configuration(cacheDb: try! __cacheDbURL(), dataDb: try! __dataDbURL())
        config.walletBirthday = self.birthdayHeight
        return config
    }
    
    static var endpoint: LightWalletEndpoint {
        return LightWalletEndpoint(address: self.host, port: self.port, secure: true)
    }
}


enum ZcashNetwork {
    case mainNet
    case testNet
}

