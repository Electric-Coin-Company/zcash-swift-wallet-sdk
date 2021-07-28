//
//  WalletBirthday+Constants.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 7/28/21.
//

import Foundation

public extension WalletBirthday {
    static func birthday(with height: BlockHeight, network: ZcashNetwork) -> WalletBirthday {
        switch network.networkType {
        case .mainnet:
            return mainnetBirthday(with: height)
        case .testnet:
            return testnetBirthday(with: height)
        }
    }
}
