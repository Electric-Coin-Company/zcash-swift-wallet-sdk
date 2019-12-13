//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/13/19.
//

import Foundation
import CommonCrypto

/**
 Thanks Stack Overflow (once again) https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
 */
public extension Data {
    struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}
