//
//  Tests+Utils.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC
class ChannelProvider {
    func channel() -> SwiftGRPC.Channel {
        Channel(address: Constants.address, secure: false)
    }
}
