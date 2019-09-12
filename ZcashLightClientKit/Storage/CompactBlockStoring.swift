//
//  CompactBlockStoring.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation


protocol CompactBlockStoring {
    
    ///
    /// Gets the highest block that is currently stored.
    ///
    
    func getLatestHeight() -> UInt64
    
    ///
    ///  Write the given blocks to this store, which may be anything from an in-memory cache to a DB.
    ///
    func write(result: [CompactBlock])

    ///
    /// Remove every block above and including the given height.
    ///
    /// After this operation, the data store will look the same as one that has not yet  stored the given block height.
    /// Meaning, if max height is 100 block and  rewindTo(50) is called, then the highest block remaining will be 49.
    ///
    func rewindTo(height: Int)
}
