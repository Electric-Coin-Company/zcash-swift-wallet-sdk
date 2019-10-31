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
}

enum ZcashNetwork {
    case mainNet
    case testNet
}
