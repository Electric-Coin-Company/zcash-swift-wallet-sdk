//
//  ZcashSDK+extensions.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/8/20.
//

import Foundation

/**
 Ideally this extension shouldn't exist. Fees should be calculated from inputs and outputs. "Perfect is the enemy of good"
 */
public extension ZcashSDK {
    
    /**
     Returns the default fee at the time of that blockheight.
     */

    static func defaultFee(for height: BlockHeight = BlockHeight.max) -> Int64 {
        guard  height >= feeChangeHeight else { return 10_000 }
        
        return 1_000
    }
    /**
     Estimated height where wallets are supposed to change the fee
     */
    private static var feeChangeHeight: BlockHeight {
        ZcashSDK.isMainnet ? 1_077_550 : 1_028_500
    }
    
    /**
        minimum balance needed to do a shielding transaction
     */
    static let shieldingThreshold: Int64 = 10000
    
    enum NetworkType {
        case mainnet
        case testnet
    }

}

public typealias ConsensusBranchID = Int32

public extension ConsensusBranchID {
    func toString() -> String {
        String(format:"%02x", self)
    }
    
    static func fromString(_ str: String) -> ConsensusBranchID? {
        guard let bitpattern = UInt32(str, radix: 16) else { return nil }
        return Int32(bitPattern: bitpattern)
    }
}

extension ZcashSDK {
    static var networkType: NetworkType {
        self.isMainnet ? .mainnet : .testnet
    }
}
extension ZcashSDK.NetworkType {
    init?(_ string: String) {
        switch string {
        case "main":
            self = .mainnet
        case "test":
            self = .testnet
        default:
            return nil
        }
    }
}
