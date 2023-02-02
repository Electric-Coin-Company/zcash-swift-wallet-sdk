//
//  ZcashCompactBlock.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public typealias BlockHeight = Int
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
    init(compactBlock: CompactBlock) {
        self.height = Int(compactBlock.height)
        self.data = (try? compactBlock.serializedData()) ?? Data()
        let outputs = compactBlock.outputCount
        self.meta = Meta(
            hash: compactBlock.hash,
            time: compactBlock.time,
            saplingOutputs: outputs.0,
            orchardOutputs: outputs.1
        )
    }
}

extension CompactBlock {
    /// O(n) sum of all CompactTx sapling outputs and Orchard Actions
    /// - Returns: a tuple (SaplingOutputs, OrchardActions)
    var outputCount: (UInt32, UInt32) {
        vtx.compactMap { compactTx -> (UInt32, UInt32) in
            (UInt32(compactTx.outputs.count), UInt32(compactTx.actions.count))
        }
        .reduce((0, 0)) { partialResult, txOutputActionPair in
            (partialResult.0 + txOutputActionPair.0, partialResult.1 + txOutputActionPair.1)
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
