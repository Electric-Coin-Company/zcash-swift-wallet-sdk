//
//  CompactBlockStoring.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

/**
A Zcash compact block to store on cache DB
*/
public struct ZcashCompactBlock: CompactBlockEntity {
    public var height: BlockHeight
    public var data: Data
}

extension ZcashCompactBlock: Encodable { }

protocol CompactBlockRepository {
    /**
    Gets the height of the highest block that is currently stored.
    */
    func latestHeight() throws -> BlockHeight
    
    /**
    Gets the highest block that is currently stored.
    Non-Blocking
    */
    func latestHeightAsync() async throws -> BlockHeight

    /**
    Write the given blocks to this store, which may be anything from an in-memory cache to a DB.
    Non-Blocking
    - Parameters:
        - Parameter blocks: array of blocks to be written to storage
        - Throws: an error when there's a failure
    */
    func write(blocks: [ZcashCompactBlock]) async throws

    /**
    Remove every block above and including the given height.
     
    After this operation, the data store will look the same as one that has not yet stored the given block height.
    Meaning, if max height is 100 block and rewindTo(50) is called, then the highest block remaining will be 49.
     
    - Parameter height: the height to rewind to
    */
    func rewind(to height: BlockHeight) throws
    
    /**
    Remove every block above and including the given height.

    After this operation, the data store will look the same as one that has not yet stored the given block height.
    Meaning, if max height is 100 block and rewindTo(50) is called, then the highest block remaining will be 49.

    - Parameter height: the height to rewind to
    */
    func rewindAsync(to height: BlockHeight) async throws
}
