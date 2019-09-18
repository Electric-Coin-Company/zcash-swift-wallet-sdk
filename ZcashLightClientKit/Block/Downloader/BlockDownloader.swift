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

protocol CompactBlockDownloading {
    
    func downloadBlockRange(_ heightRange: CompactBlockRange,
                            completion: @escaping (Error?) -> Void)
    
    func rewind(to height: BlockHeight) throws
    
    func latestBlockHeight() throws -> BlockHeight
    
}


class CompactBlockDownloader {
    
    fileprivate var lightwalletService: LightWalletService
    fileprivate var storage: CompactBlockAsyncStoring
    
    init(service: LightWalletService, storage: CompactBlockAsyncStoring) {
        self.lightwalletService = service
        self.storage = storage
    }
}

extension CompactBlockDownloader: CompactBlockDownloading {
    
    /**
     Downloads and stores the given block range.
     */
    func downloadBlockRange(_ heightRange: CompactBlockRange,
                            completion: @escaping (Error?) -> Void) {
        
        lightwalletService.blockRange(heightRange) { [weak self] (result) in
            
            guard let self = self else {
                return
            }
            
            switch result{
            case .failure(let error):
                completion(error)
                return
            case .success(let compactBlocks):
                self.storage.write(blocks: compactBlocks) { (storeError) in
                    completion(storeError)
                }
            }
        }
        
    }
    
    
    func rewind(to height: BlockHeight) throws {
        // remove this horrible function
        var waiting = true
        var error: Error? = nil
        storage.rewind(to: height) { (e) in
            waiting = false
            if let err = e {
                error = CompactBlockDownloadError.generalError(error: err)
                return
            }
            
        }
        
        while waiting {
            sleep(1)
        }
        
        if let error  = error {
            throw error
        }
        return
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        // remove this horrible function
        var waiting = true
        var error: Error? = nil
        var blockHeight: BlockHeight = 0
        storage.latestHeight { (result) in
            
            waiting = false
            switch result {
            case .failure(let e):
                error = CompactBlockDownloadError.generalError(error: e)
                return
            case .success(let height):
                blockHeight = height
            }
            
        }
        
        while waiting {
            sleep(1)
        }
        
        if let error = error {
            throw error
        }
        return blockHeight
    }
    
}

