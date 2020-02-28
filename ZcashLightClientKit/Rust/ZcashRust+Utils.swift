//
//  ZcashRust+Utils.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension Data {
    func asZcashTransactionMemo() -> String? {
        return String(bytes: self, encoding: .utf8)
    }
}

extension String {
    func encodeAsZcashTransactionMemo() -> Data? {
        return self.data(using: .utf8)
    }
}
