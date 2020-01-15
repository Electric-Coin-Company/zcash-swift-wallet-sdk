//
//  Data+Zcash.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 1/10/20.
//

import Foundation

public extension Data {
    
    func toHexStringTxId() -> String {
        self.hexEncodedString().toTxIdString()
    }
    
}
extension String {
    func toTxIdString() -> String {
        var id = ""
        self.reversed().pairs.map {
            $0.reversed()
        }.forEach { (reversed) in
            id.append(String(reversed))
        }
        return id
    }
}

extension Collection {
    var pairs: [SubSequence] {
        var startIndex = self.startIndex
        let count = self.count
        let n = count / 2 + count % 2
        return (0..<n).map { _ in
            let endIndex = index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return self[startIndex..<endIndex]
        }
    }
}
