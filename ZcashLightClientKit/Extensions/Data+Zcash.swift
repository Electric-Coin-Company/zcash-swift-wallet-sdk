//
//  Data+Zcash.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 1/10/20.
//

import Foundation

public extension Data {
    
    func toHexStringTxId() -> String {
        String(self.hexEncodedString().reversed())
    }
    
}
