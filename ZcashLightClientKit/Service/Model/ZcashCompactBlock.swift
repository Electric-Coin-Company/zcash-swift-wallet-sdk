//
//  ZcashCompactBlock.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public struct ZcashCompactBlock {
    var height: UInt64
    var data: Data
}


extension ZcashCompactBlock {
    init?(compactBlock: CompactBlock) {
        do {
            self.height = compactBlock.height
            self.data = try compactBlock.serializedData()
        } catch {
            return nil
        }
    }
}

extension ZcashCompactBlock: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.height != rhs.height {
            return false
        }
        
        return lhs.data == rhs.data
    }
}

extension ZcashCompactBlock: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(height)
        hasher.combine(data)
    }
}


