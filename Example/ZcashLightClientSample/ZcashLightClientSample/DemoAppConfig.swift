//
//  DemoAppConfig.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 10/31/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import ZcashLightClientKit
import MnemonicKit
struct DemoAppConfig {
    static var host = ZcashSDK.isMainnet ? "lightwalletd.z.cash" : "lightwalletd.testnet.z.cash"
    static var port: Int = 9067
    static var birthdayHeight: BlockHeight = ZcashSDK.isMainnet ? 735_000 : 620_000
    static var network = ZcashSDK.isMainnet ? ZcashNetwork.mainNet : ZcashNetwork.testNet
    static var seed = ZcashSDK.isMainnet ? Mnemonic.deterministicSeedBytes(from: "wish puppy smile loan doll curve hole maze file ginger hair nose key relax knife witness cannon grab despair throw review deal slush frame")! : Array("testreferencealicetestreferencealice".utf8)
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

