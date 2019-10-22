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
    case dataDbInitFailed(path: String)
}

extension Notification.Name {
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    static let blockProcessorStarted = Notification.Name(rawValue: "CompactBlockProcessorStarted")
    static let blockProcessorStopped = Notification.Name(rawValue: "CompactBlockProcessorStopped")
    static let blockProcessorFinished = Notification.Name(rawValue: "CompactBlockProcessorFinished")
    static let blockProcessorFailed = Notification.Name(rawValue: "CompactBlockProcessorFinished")
}

class CompactBlockProcessor {
    /**
     Compact Block Processor configuration
     
     Property: cacheDbPath absolute file path of the DB where raw, unprocessed compact blocks are stored.
     Property: dataDbPath absolute file path of the DB where all information derived from the cache DB is stored.
     */
    
    struct Configuration {
        var cacheDb: URL
        var dataDb: URL
        var downloadBatchSize = DEFAULT_BATCH_SIZE
        var blockPollInterval = DEFAULT_POLL_INTERVAL
        var retries = DEFAULT_RETRIES
        var maxBackoffInterval = DEFAULT_MAX_BACKOFF_INTERVAL
        var rewindDistance = DEFAULT_REWIND_DISTANCE
        
    }
    
    enum State {
        
        /**
         connected and downloading blocks
         */
        case connected
        
        /**
         was doing something but was paused
         */
        case stopped
        /**
         processor is scanning
         */
        case scanning
        /**
         was processing but erred
         */
        case error
        
        /**
         Just chillin'
         */
        case idle
    }
    
    private(set) var state: State = .idle
    
    private var downloader: CompactBlockDownloading
    private var rustBackend: ZcashRustBackendWelding.Type
    private var config: Configuration = Configuration.standard
    private var service: LightWalletService
    private var queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    } ()
    private var retryAttempts = 0
    private var backoffTimer: Timer?
    // convenience vars
    private var maxAttempts: Int {
        config.retries
    }
    
    private var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }
    
    private var processingError: Error?
    
    init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration, service: LightWalletService) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
        self.service = service
        suscribeToSystemNotifications()
        
    }
    
    private func suscribeToSystemNotifications() {
        // TODO: check system notifications for connections and application context changes
    }
    
    private func unsuscribeToSystemNotifications() {
        
    }
    
    deinit {
        self.queue.cancelAllOperations()
        self.unsuscribeToSystemNotifications()
    }
    
    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.cacheDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.cacheDb.absoluteString)
        }
        
        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDb.absoluteString)
        }
    }
    
    func start() throws {
        // TODO: Handle Background task
        
        try validateConfiguration()
        
        guard rustBackend.initDataDb(dbData: config.dataDb) else {
            throw CompactBlockProcessorError.dataDbInitFailed(path: config.dataDb.absoluteString)
        }
        
        var latestBlockHeight: BlockHeight = 0
        
        // get latest block height
        
        let latestDownloadedBlockHeight: BlockHeight = try downloader.latestBlockHeight()
        
        // get latest block height from ligthwalletd
        
        self.service.latestBlockHeight { (result) in
            switch result {
            case .success(let blockHeight):
                latestBlockHeight = blockHeight
                
                self.processNewBlocks(latestHeight: latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight)
            case .failure(let e):
                DispatchQueue.main.async {
                    self.fail(e)
                }
            }
        }
    }
    
    func processNewBlocks(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) {
        
        NotificationCenter.default.post(name: Notification.Name.blockProcessorStarted, object: self)
        var err: Error?
        let blockOperation = BlockOperation {
            self.state = .connected
            var currentHeight = latestDownloadedHeight
            let cfg = self.config
            while err != nil || latestDownloadedHeight > latestDownloadedHeight {
                do {
                    try self.downloader.downloadBlockRange(CompactBlockRange(uncheckedBounds: (lower: currentHeight, upper: min(latestDownloadedHeight + cfg.downloadBatchSize,latestHeight))))
                    currentHeight = try self.downloader.latestBlockHeight()
                    print("progress: \(currentHeight / latestHeight)")
                } catch {
                    err = error
                }
            }
        }
        
        blockOperation.completionBlock =  {
            if let error = err {
                self.fail(error)
            }
        }
        queue.addOperation(blockOperation)
        
    }
    
    private func processBatchFinished(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) {
        
        guard processingError == nil else {
            retryProcessing(latestHeight: latestHeight, latestDownloadedHeight: latestDownloadedHeight)
            return
        }
        retryAttempts = 0
        guard latestDownloadedHeight < latestHeight else {
            processingFinished()
            return
        }
    }
    
    private func processingFinished() {
        self.state = .idle
        self.backoffTimer = Timer(timeInterval: TimeInterval(self.config.blockPollInterval), repeats: true, block: { _ in
            do {
                try self.start()
            } catch {
                self.fail(error)
                
            }
        })
    }
    private func nextBatchBlockRange(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) -> CompactBlockRange {
        return CompactBlockRange(uncheckedBounds: (latestDownloadedHeight + 1, min(latestDownloadedHeight + BlockHeight(DEFAULT_BATCH_SIZE), latestDownloadedHeight)))
    }
    
    func retryProcessing(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) {
        
        processNewBlocks(latestHeight: latestHeight, latestDownloadedHeight: latestDownloadedHeight)
    }
    
    func stop() {
        queue.cancelAllOperations()
        self.state = .stopped
    }
    
    func fail(_ error: Error) {
        // todo specify: failure
        print(error.localizedDescription)
        queue.cancelAllOperations()
        self.processingError = error
        self.state = .error
        
        NotificationCenter.default.post(name: Notification.Name.blockProcessorFailed, object: self, userInfo: ["error": error ])
    }
}

extension CompactBlockProcessor.Configuration {
    static var standard: CompactBlockProcessor.Configuration {
        
        let pathProvider = DefaultResourceProvider()
        
        return CompactBlockProcessor.Configuration(cacheDb: pathProvider.cacheDbURL, dataDb: pathProvider.dataDbURL)
        
    }
}
