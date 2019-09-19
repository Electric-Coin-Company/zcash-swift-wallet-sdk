//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation


enum  CompactBlockProcessorError: Error {
    case invalidConfiguration
    case missingDbPath(path: String)
}

class CompactBlockProcessor {
    
     
    enum State {
           case connected
           case stopped
           case scanning
    }
       
    private(set) var state: State = .stopped
    
    private var downloader: CompactBlockDownloading
    private var rustBackend: ZcashRustBackendWelding
    private var config: Configuration = Configuration.standard
    
    init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding, config: Configuration) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
    }
    
    /**
       Compact Block Processor configuration
     
       Property: cacheDbPath absolute file path of the DB where raw, unprocessed compact blocks are stored.
       Property: dataDbPath absolute file path of the DB where all information derived from the cache DB is stored.
     */
     
    struct Configuration {
        var cacheDbPath: String
        var dataDbPath: String
        var downloadBatchSize = DEFAULT_BATCH_SIZE
        var blockPollInterval = DEFAULT_POLL_INTERVAL
        var retries = DEFAULT_RETRIES
        var maxBackoffInterval = DEFAULT_MAX_BACKOFF_INTERVAL
        var rewindDistance = DEFAULT_REWIND_DISTANCE
        
    }
    
    private func validateConfiguration() throws {
        guard FileManager.default.fileExists(atPath: config.cacheDbPath) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.cacheDbPath)
        }
        
        guard FileManager.default.fileExists(atPath: config.dataDbPath) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDbPath)
        }

    }

    func start() throws {
        
        try validateConfiguration()
        
        
    }
    
    func stop() {}
    
    
    
    
}


extension CompactBlockProcessor.Configuration {
   static var standard: CompactBlockProcessor.Configuration {
        
        let pathProvider = DefaultResourceProvider()
        
        return CompactBlockProcessor.Configuration(cacheDbPath: pathProvider.cacheDbPath, dataDbPath: pathProvider.dataDbPath)

    }

}
