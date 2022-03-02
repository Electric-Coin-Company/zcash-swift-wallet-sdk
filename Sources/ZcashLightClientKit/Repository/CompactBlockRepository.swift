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
    Gets the highest block that is currently stored.
    */
    
    func latestHeight() throws -> BlockHeight
    
    /**
    Gets the highest block that is currently stored.
    Non-Blocking
     
    - Parameter result: closure resulting on either the latest height or an error
    */
    func latestHeight(result: @escaping (Result<BlockHeight, Error>) -> Void)
    
    /**
    Write the given blocks to this store, which may be anything from an in-memory cache to a DB.
    Blocking
    - Parameter blocks: the compact blocks that will be written to storage
    - Throws: an error when there's a failure
    */
    func write(blocks: [ZcashCompactBlock]) throws
    
    /**
    Write the given blocks to this store, which may be anything from an in-memory cache to a DB.
    Non-Blocking
    - Parameters:
        - Parameter blocks: array of blocks to be written to storage
        - Parameter completion: a closure that will be called after storing the blocks
    */
    func write(blocks: [ZcashCompactBlock], completion: ((Error?) -> Void)?)
    
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

    - Parameters:
    - Parameter height: the height to rewind to
    - Parameter completion: a closure that will be called after storing the blocks

    */
    func rewind(to height: BlockHeight, completion: ((Error?) -> Void)?)
}
