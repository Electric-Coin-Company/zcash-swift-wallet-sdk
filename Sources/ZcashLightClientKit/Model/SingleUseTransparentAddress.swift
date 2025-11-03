//
//  SingleUseTransparentAddress.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-10-27.
//

import Foundation

public struct SingleUseTransparentAddress: Equatable {
    let address: String
    let gapPosition: UInt32
    let gapLimit: UInt32
    
    public init(address: String, gapPosition: UInt32, gapLimit: UInt32) {
        self.address = address
        self.gapPosition = gapPosition
        self.gapLimit = gapLimit
    }
}

public enum TransparentAddressCheckResult: Equatable {
    case notFound
    case found(String)
}
