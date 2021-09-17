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
    func downloadBlockRange(
        _ heightRange: CompactBlockRange,
        completion: @escaping (Error?) -> Void
    )
    
    /**
    Remove newer blocks and go back to the given height
    - Parameters:
        - height: the given height to rewind to
        - completion: block to be executed after completing rewind
    */
    func rewind(to height: BlockHeight, completion: @escaping (Error?) -> Void)
    
    /**
    returns the height of the latest compact block stored locally
    BlockHeight.empty() if no blocks are stored yet
    non-blocking
    */
    func lastDownloadedBlockHeight(result: @escaping (Result<BlockHeight, Error>) -> Void)
    
    /**
    Returns the last height on the blockchain
    Non-blocking
    */
    func latestBlockHeight(result: @escaping (Result<BlockHeight, Error>) -> Void)
    
    /**
    Downloads and stores the given block range.
    Blocking
    */
    func downloadBlockRange(_ range: CompactBlockRange) throws
    
    /**
    Restore the download progress up to the given height.
    */
    func rewind(to height: BlockHeight) throws

    /**
    Returns the height of the latest compact block stored locally.
    BlockHeight.empty() if no blocks are stored yet
    Blocking
    */
    func lastDownloadedBlockHeight() throws -> BlockHeight
    
    /**
    Returns the latest block height
    Blocking
    */
    func latestBlockHeight() throws -> BlockHeight
    
    /**
    Gets the transaction for the Id given
    - Parameter txId: Data representing the transaction Id
    - Returns: a transaction entity with the requested transaction
    - Throws: An error if the fetch failed
    */
    func fetchTransaction(txId: Data) throws -> TransactionEntity
    
    /**
    Gets the transaction for the Id given
    - Parameter txId: Data representing the transaction Id
    - Parameter result: a handler for the result of the operation
    */
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, Error>) -> Void)
    
    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight) throws -> [UnspentTransactionOutputEntity]
    
    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight, result: @escaping (Result<[UnspentTransactionOutputEntity], Error>) -> Void)
    
    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight) throws -> [UnspentTransactionOutputEntity]
    
    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight, result: @escaping (Result<[UnspentTransactionOutputEntity], Error>) -> Void)
    
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
    
    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        try lightwalletService.fetchUTXOs(for: tAddresses, height: startHeight)
    }
    
    func fetchUnspentTransactionOutputs(
        tAddresses: [String],
        startHeight: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], Error>) -> Void
    ) {
        lightwalletService.fetchUTXOs(for: tAddresses, height: startHeight) { fetchResult in
            switch fetchResult {
            case .success(let utxos):
                result(.success(utxos))
            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        try lightwalletService.fetchUTXOs(for: tAddress, height: startHeight)
    }
    
    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight, result: @escaping (Result<[UnspentTransactionOutputEntity], Error>) -> Void) {
        lightwalletService.fetchUTXOs(for: tAddress, height: startHeight) { fetchResult in
            switch fetchResult {
            case .success(let utxos):
                result(.success(utxos))
            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, Error>) -> Void) {
        lightwalletService.latestBlockHeight { fetchResult in
            switch fetchResult {
            case .failure(let error):
                result(.failure(error))
            case .success(let height):
                result(.success(height))
            }
        }
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        try lightwalletService.latestBlockHeight()
    }
    
    /**
    Downloads and stores the given block range.
    Non-Blocking
    */
    func downloadBlockRange(
        _ heightRange: CompactBlockRange,
        completion: @escaping (Error?) -> Void
    ) {
        lightwalletService.blockRange(heightRange) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .failure(let error):
                completion(error)
            case .success(let compactBlocks):
                self.storage.write(blocks: compactBlocks) { storeError in
                    completion(storeError)
                }
            }
        }
    }
    
    func downloadBlockRange(_ range: CompactBlockRange) throws {
        let blocks = try lightwalletService.blockRange(range)
        try storage.write(blocks: blocks)
    }
    
    func rewind(to height: BlockHeight, completion: @escaping (Error?) -> Void) {
        storage.rewind(to: height) { e in
            completion(e)
        }
    }
    
    func lastDownloadedBlockHeight(result: @escaping (Result<BlockHeight, Error>) -> Void) {
        storage.latestHeight { heightResult in
            switch heightResult {
            case .failure(let e):
                result(.failure(CompactBlockDownloadError.generalError(error: e)))
                return
            case .success(let height):
                result(.success(height))
            }
        }
    }
    
    func rewind(to height: BlockHeight) throws {
        try self.storage.rewind(to: height)
    }
    
    func lastDownloadedBlockHeight() throws -> BlockHeight {
        try self.storage.latestHeight()
    }
    
    func fetchTransaction(txId: Data) throws -> TransactionEntity {
        try lightwalletService.fetchTransaction(txId: txId)
    }
    
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, Error>) -> Void) {
        lightwalletService.fetchTransaction(txId: txId) { txResult in
            switch txResult {
            case .failure(let error):
                result(.failure(error))
            case .success(let transaction):
                result(.success(transaction))
            }
        }
    }
}
