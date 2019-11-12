//
//  DemoAppConfig.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 10/31/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import ZcashLightClientKit

struct DemoAppConfig {
    static var host = "34.68.177.238"
    static var port = "9067"
    static var birthdayHeight: BlockHeight = 620_000
    static var network = ZcashNetwork.testNet
    static var seed = Array("testreferencealice".utf8)    
    static var address: String {
        "\(host):\(port)"
    }
    
    static var processorConfig: CompactBlockProcessor.Configuration {
        var config = CompactBlockProcessor.Configuration(cacheDb: try! __cacheDbURL(), dataDb: try! __dataDbURL())
        config.walletBirthday = self.birthdayHeight
        return config
    }
    
    static var endpoint: LightWalletEndpoint {
        return LightWalletEndpoint(address: self.host, port: self.port, secure: false)
    }
}


enum ZcashNetwork {
    case mainNet
    case testNet
}

