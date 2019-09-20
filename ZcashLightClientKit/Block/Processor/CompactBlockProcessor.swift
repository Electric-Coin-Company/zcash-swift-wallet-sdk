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

extension Notification.Name {
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    static let blockProcessorStarted = Notification.Name(rawValue:"CompactBlockProcessorStarted")
    static let blockProcessorStopped = Notification.Name(rawValue:"CompactBlockProcessorStopped")
    static let blockProcessorFinished = Notification.Name(rawValue:"CompactBlockProcessorFinished")
    static let blockProcessorFailed = Notification.Name(rawValue:"CompactBlockProcessorFinished")
}


class CompactBlockProcessor {
    
    
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
    private var queue = DispatchQueue(label: "CompactBlockProcessor-Queue")
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
        self.queue.suspend()
        self.unsuscribeToSystemNotifications()
        
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
        var latestDownloadedBlockHeight: BlockHeight = 0
        var latestBlockHeight: BlockHeight = 0
        let dispatchGroup = DispatchGroup()
        
        let downloadedHeightItem = DispatchWorkItem {
            dispatchGroup.enter()
            self.downloader.latestBlockHeight { (heightResult) in
                switch heightResult {
                case .success(let downloadedHeight):
                    latestDownloadedBlockHeight = downloadedHeight
                    
                case .failure(let e):
                    DispatchQueue.main.async {
                        self.fail(e)
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        let latestBlockHeightItem = DispatchWorkItem {
            dispatchGroup.enter()
            self.service.latestBlockHeight { (result) in
                switch result {
                case .success(let blockHeight):
                    latestBlockHeight = blockHeight
                case .failure(let e):
                    DispatchQueue.main.async {
                        self.fail(e)
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        queue.async(execute: downloadedHeightItem)
        queue.async(execute: latestBlockHeightItem)
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("downloaded BlockHeight Value: \(latestDownloadedBlockHeight)")
            print("latest BlockHeight Value:\(latestBlockHeight)")
            
            guard self.state != .error else {
                return
            }
            
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStarted, object: self)
            
            self.processNewBlocks(latestHeight: latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight)
        }
        
        
    }
    
    func processNewBlocks(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) {
        
        let dispatchGroup = DispatchGroup()
        
        
        let validateBlocksTask = DispatchWorkItem {
            dispatchGroup.enter()
            self.state = .scanning
            
        }
        
        let downloadTask = DispatchWorkItem {
            dispatchGroup.enter()
            self.state = .connected
            self.downloader.downloadBlockRange(self.nextBatchBlockRange(latestHeight: latestHeight, latestDownloadedHeight: latestDownloadedHeight)) { (error) in
                
                if let error = error {
                    validateBlocksTask.cancel()
                    self.fail(error)
                }
                dispatchGroup.leave()
            }
        }
        queue.async(execute: downloadTask)
        queue.async(execute: validateBlocksTask)
        dispatchGroup.notify(queue: DispatchQueue.main) {
            self.processBatchFinished(latestHeight: latestHeight, latestDownloadedHeight: latestDownloadedHeight)
        }
        
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
        queue.suspend()
        self.state = .stopped
    }
    
    
    func fail(_ error: Error) {
        // todo specify: failure
        print(error.localizedDescription)
        self.processingError = error
        self.state = .error
        
        NotificationCenter.default.post(name: Notification.Name.blockProcessorFailed, object: self, userInfo: ["error": error ])
    }
    
}


extension CompactBlockProcessor.Configuration {
    static var standard: CompactBlockProcessor.Configuration {
        
        let pathProvider = DefaultResourceProvider()
        
        return CompactBlockProcessor.Configuration(cacheDbPath: pathProvider.cacheDbPath, dataDbPath: pathProvider.dataDbPath)
        
    }
    
}
