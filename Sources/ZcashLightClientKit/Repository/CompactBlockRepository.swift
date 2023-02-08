//
//  CompactBlockStoring.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum CompactBlockRepositoryError: Error, Equatable {
    /// cache is empty
    case cacheEmpty
    /// It was expected to have some cache entry but upon retrieval
    /// it couldn't be parsed.
    case malformedCacheEntry(String)
    /// There was a failure when attempting to clear the repository
    case cacheClearFailed
    /// There was a problem storing a given block
    case failedToWriteBlock(ZcashCompactBlock)
    /// there was a problem saving the metadata of the cached blocks
    /// the underlying error is returned as the associated value
    case failedToWriteMetadata
    /// failed to initialize cache with no underlying error
    case failedToInitializeCache
    /// failed to rewind the repository to given blockheight
    case failedToRewind(BlockHeight)
}

protocol CompactBlockRepository {
    /// Creates the underlying repository
    func create() throws

    /**
    Gets the height of the highest block that is currently stored.
    */
    func latestHeight() -> BlockHeight
    
    /**
    Gets the highest block that is currently stored.
    Non-Blocking
    */
    func latestHeightAsync() async -> BlockHeight

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
    Removes every block above and including the given height.

    After this operation, the data store will look the same as one that has not yet stored the given block height.
    Meaning, if max height is 100 block and rewindTo(50) is called, then the highest block remaining will be 49.

    - Parameter height: the height to rewind to
    */
    func rewindAsync(to height: BlockHeight) async throws

    /// Clears the repository
    func clear() async throws
}

extension CompactBlockRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToWriteBlock(let block):
            return "Failed to write compact block of height \(block.height)."
        case .malformedCacheEntry(let message):
            return "Malformed cache entry: \(message)."
        case .cacheEmpty:
            return "Cache is Empty."
        case .cacheClearFailed:
            return "Cache could not be cleared."
        case .failedToWriteMetadata:
            return "Failed to write metadata to FsBlockDb."
        case .failedToInitializeCache:
            return "Failed to initialize metadata FsBlockDb."
        case .failedToRewind(let height):
            return "Failed to rewind FsBlockDb to height \(height)."
        }
    }
}
