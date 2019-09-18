//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class CompactBlockProcessor {
    enum State {
           case connected
           case stopped
           case scanning
    }
       
    private(set) var state: State = .stopped
}
