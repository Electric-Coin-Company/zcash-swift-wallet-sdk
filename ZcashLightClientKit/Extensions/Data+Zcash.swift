//
//  Data+Zcash.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 1/10/20.
//

import Foundation

public extension Data {
    /**
     Transforms the data info bytes into a Zcash hex transaction id
     */
    func toHexStringTxId() -> String {
        self.hexEncodedString().toTxIdString()
    }

}
