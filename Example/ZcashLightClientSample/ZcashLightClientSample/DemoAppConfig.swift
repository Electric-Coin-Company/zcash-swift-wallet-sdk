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
// swiftlint:disable line_length force_try
enum DemoAppConfig {
    static var host = ZcashSDK.isMainnet ? "lightwalletd.electriccoin.co" : "lightwalletd.testnet.electriccoin.co"
    static var port: Int = 9067
    static var birthdayHeight: BlockHeight = ZcashSDK.isMainnet ? 935000 : 1386000
    
    static var seed = try! Mnemonic.deterministicSeedBytes(from: "live combine flight accident slow soda mind bright absent bid hen shy decade biology amazing mix enlist ensure biology rhythm snap duty soap armor")
    static var address: String {
        "\(host):\(port)"
    }
    
    static var processorConfig: CompactBlockProcessor.Configuration  = {
        CompactBlockProcessor.Configuration(
            cacheDb: try! cacheDbURLHelper(),
            dataDb: try! dataDbURLHelper(),
            walletBirthday: Self.birthdayHeight,
            network: kZcashNetwork
        )
    }()
    
    static var endpoint: LightWalletEndpoint {
        return LightWalletEndpoint(address: self.host, port: self.port, secure: true)
    }
}

extension ZcashSDK {
    static var isMainnet: Bool {
        switch kZcashNetwork.networkType {
        case .mainnet:  return true
        case .testnet:  return false
        }
    }
}
