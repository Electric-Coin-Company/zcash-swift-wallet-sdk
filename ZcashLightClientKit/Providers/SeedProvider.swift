//
//  SeedProvider.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public protocol SeedProvider {
    func seed() -> [UInt8]
}
