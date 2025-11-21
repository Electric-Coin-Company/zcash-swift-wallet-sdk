//
//  Data+internal.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/23/20.
//

import Foundation

extension String {
    func toTxIdString() -> String {
        var id = ""
        self.reversed().pairs
            .map {
                $0.reversed()
            }
            .forEach { reversed in
                id.append(String(reversed))
            }
        return id
    }
    
    func txIdToBytes() -> [UInt8]? {
        guard self.count == 64 else {
            return nil
        }
        
        var bytes: [UInt8] = []
        bytes.reserveCapacity(count / 2)
        
        var index = startIndex
        
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2)
            let byteString = self[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            } else {
                return [] // or throw error
            }
            index = nextIndex
        }
        
        return bytes
    }
}

extension Collection {
    var pairs: [SubSequence] {
        var startIndex = self.startIndex
        let count = self.count
        let halving = count / 2 + count % 2
        return (0..<halving).map { _ in
            let endIndex = index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return self[startIndex..<endIndex]
        }
    }
}
