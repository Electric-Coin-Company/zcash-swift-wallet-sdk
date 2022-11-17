//
//  BlockDownloader.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 17/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum CompactBlockDownloadError: Error {
    case timeout
    case generalError(error: Error)
}
/**
Represents what a compact block downloaded should provide to its clients
*/
public protocol CompactBlockDownloading {
    /**
    Downloads and stores the given block range.
    Non-Blocking
    */
    func downloadBlockRange(_ heightRange: CompactBlockRange) async throws

    /**
    Restore the download progress up to the given height.
    */
    func rewind(to height: BlockHeight) throws

    /**
    Remove newer blocks and go back to the given height
    - Parameter height: the given height to rewind to
    */
    func rewindAsync(to height: BlockHeight) async throws

    /**
    Returns the height of the latest compact block stored locally.
    BlockHeight.empty() if no blocks are stored yet
    Blocking
    */
    func lastDownloadedBlockHeight() throws -> BlockHeight

    /**
    returns the height of the latest compact block stored locally
    BlockHeight.empty() if no blocks are stored yet
    non-blocking
    */
    func lastDownloadedBlockHeightAsync() async throws -> BlockHeight

    /**
    Returns the latest block height
    Blocking
    */
    func latestBlockHeight() throws -> BlockHeight

    /**
    Returns the last height on the blockchain
    Non-blocking
    */
    func latestBlockHeightAsync() async throws -> BlockHeight

    /**
    Gets the transaction for the Id given
    - Parameter txId: Data representing the transaction Id
    */
    func fetchTransaction(txId: Data) async throws -> TransactionEntity

    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>

    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>
    
    func closeConnection()
}

/**
Serves as a source of compact blocks received from the light wallet server. Once started, it will use the given
lightwallet service to request all the appropriate blocks and compact block store to persist them. By delegating to
these dependencies, the downloader remains agnostic to the particular implementation of how to retrieve and store
data; although, by default the SDK uses gRPC and SQL.
- Property lightwalletService: the service used for requesting compact blocks
- Property storage: responsible for persisting the compact blocks that are received
*/
class CompactBlockDownloader {
    var lightwalletService: LightWalletService
    private(set) var storage: CompactBlockRepository
    
    init(service: LightWalletService, storage: CompactBlockRepository) {
        self.lightwalletService = service
        self.storage = storage
    }
}

extension CompactBlockDownloader: CompactBlockDownloading {
    func closeConnection() {
        lightwalletService.closeConnection()
    }
            
    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight ) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        lightwalletService.fetchUTXOs(for: tAddresses, height: startHeight)
    }
    
    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        lightwalletService.fetchUTXOs(for: tAddress, height: startHeight)
    }
    
    func latestBlockHeightAsync() async throws -> BlockHeight {
        try await lightwalletService.latestBlockHeightAsync()
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        try lightwalletService.latestBlockHeight()
    }

    func downloadBlockRange( _ heightRange: CompactBlockRange) async throws {
        let stream: AsyncThrowingStream<ZcashCompactBlock, Error> = lightwalletService.blockRange(heightRange)
        do {
            var compactBlocks: [ZcashCompactBlock] = []
            for try await compactBlock in stream {
                compactBlocks.append(compactBlock)
            }
            try await self.storage.write(blocks: compactBlocks)
        } catch {
            throw error
        }
    }
    
    func rewindAsync(to height: BlockHeight) async throws {
        do {
            try await storage.rewindAsync(to: height)
        } catch {
            throw error
        }
    }
    
    func lastDownloadedBlockHeightAsync() async throws -> BlockHeight {
        do {
            let latestHeight = try await storage.latestHeightAsync()
            return latestHeight
        } catch {
            throw CompactBlockDownloadError.generalError(error: error)
        }
    }

    func rewind(to height: BlockHeight) throws {
        try self.storage.rewind(to: height)
    }
    
    func lastDownloadedBlockHeight() throws -> BlockHeight {
        try self.storage.latestHeight()
    }
    
    func fetchTransaction(txId: Data) async throws -> TransactionEntity {
        try await lightwalletService.fetchTransaction(txId: txId)
    }
}
