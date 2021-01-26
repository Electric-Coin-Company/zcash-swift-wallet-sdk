//
//  ZcashCompactBlock.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public typealias BlockHeight = Int
public typealias Network = String
public typealias CompactBlockRange = ClosedRange<BlockHeight>

enum ZcashCompactBlockError: Error {
    case unreadableBlock(compactBlock: CompactBlock)
}

extension BlockHeight {
    static func empty() -> BlockHeight {
        BlockHeight(-1)
    }
}

extension ZcashCompactBlock {
    init?(compactBlock: CompactBlock) {
        do {
            // Safe to try: 32-bit systems will nil 
            guard let h = Int(exactly: compactBlock.height) else { return nil }
            self.height = h
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
