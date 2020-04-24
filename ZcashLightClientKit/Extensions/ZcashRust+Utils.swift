//
//  ZcashRust+Utils.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
/**
 Attempts to show the data as a Zcash Transaction Memo
 */
public extension Data {
    func asZcashTransactionMemo() -> String? {
        
        self.withUnsafeBytes { (rawPointer) -> String? in
            let unsafeBufferPointer = rawPointer.bindMemory(to: CChar.self)
            if let unsafePointer = unsafeBufferPointer.baseAddress, let utf8Memo = String(validatingUTF8: unsafePointer) {
                return utf8Memo.isEmpty ? nil : utf8Memo
            } else {
                return nil
            }
        }
    }
}

/**
 Attempts to convert this string to a Zcash Transaction Memo data
 */
public extension String {
    func encodeAsZcashTransactionMemo() -> Data? {
        return self.data(using: .utf8)
    }
}
