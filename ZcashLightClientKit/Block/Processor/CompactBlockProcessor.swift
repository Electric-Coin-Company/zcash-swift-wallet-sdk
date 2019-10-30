//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum CompactBlockProcessorError: Error {
    case invalidConfiguration
    case missingDbPath(path: String)
    case dataDbInitFailed(path: String)
}

extension Notification.Name {
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    static let blockProcessorStartedDownloading = Notification.Name(rawValue: "CompactBlockProcessorStartedDownloading")
    static let blockProcessorStartedValidating = Notification.Name(rawValue: "CompactBlockProcessorStartedValidating")
    static let blockProcessorStartedScanning = Notification.Name(rawValue: "CompactBlockProcessorStartedScanning")
    static let blockProcessorStopped = Notification.Name(rawValue: "CompactBlockProcessorStopped")
    static let blockProcessorFailed = Notification.Name(rawValue: "CompactBlockProcessorFailed")
    static let blockProcessorIdle = Notification.Name(rawValue: "CompactBlockProcessorIdle")
    static let blockProcessorUnknownTransition = Notification.Name(rawValue: "CompactBlockProcessorTransitionUnknown")
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
        var walletBirthday = SAPLING_ACTIVATION_HEIGHT
    }
    
    enum State {
        
        /**
         connected and downloading blocks
         */
        case downloading
        
        /**
         was doing something but was paused
         */
        case stopped
        /**
        processor is validating
         */
        case validating
        /**
        processor is scanning
         */
        case scanning
        /**
         was processing but erred
         */
        case error(_ e: Error)
        
        /**
         Processor is up to date with the blockchain and  you can now make trasnsactions.
         */
        case synced
        
    }
    
    private(set) var state: State = .synced {
        didSet {
            transitionState(from: oldValue, to: self.state)
        }
    }
    
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
    
    private var latestBlockHeight: BlockHeight
    private var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }
    
    private var processingError: Error?
    
    init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration, service: LightWalletService) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
        self.service = service
        self.latestBlockHeight = config.walletBirthday
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
        
        // TODO: check if this validation makes sense at all
        //        try validateConfiguration()
        
        guard rustBackend.initDataDb(dbData: config.dataDb) else {
            throw CompactBlockProcessorError.dataDbInitFailed(path: config.dataDb.absoluteString)
        }
        
        try nextBatch()
    }
    
    private func nextBatch() throws {
        // get latest block height
        
        let latestDownloadedBlockHeight: BlockHeight = max(config.walletBirthday,try downloader.latestBlockHeight())
        
        // get latest block height from ligthwalletd
        
        if self.latestBlockHeight > latestDownloadedBlockHeight {
            self.processNewBlocks(range: self.nextBatchBlockRange(latestHeight: self.latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight))
        } else {
            self.service.latestBlockHeight { (result) in
                switch result {
                case .success(let blockHeight):
                    self.latestBlockHeight = blockHeight
                    
                    self.processNewBlocks(range: self.nextBatchBlockRange(latestHeight: self.latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight))
                case .failure(let e):
                    DispatchQueue.main.async {
                        self.fail(e)
                    }
                }
            }
        }
    }
    
    func processNewBlocks(range: CompactBlockRange) {
        guard !range.isEmpty else {
            processingFinished()
            return
        }
        
        let cfg = self.config
        
        let downloadBlockOperation = CompactBlockDownloadOperation(downloader: self.downloader, range: range)
        
        downloadBlockOperation.startedHandler = {
            self.state = .downloading
        }
        
        downloadBlockOperation.errorHandler = { (error) in
            self.processingError = error
            self.fail(error)
        }
        
        let validateChainOperation = CompactBlockValidationOperation(rustWelding: self.rustBackend, cacheDb: cfg.cacheDb, dataDb: cfg.dataDb)
        
        validateChainOperation.completionHandler = { (finished, cancelled) in
            guard !cancelled else {
                               print("Warning: operation cancelled")
                           return
                       }
            
            print("validateChainFinished")
        }
        
        validateChainOperation.errorHandler = { (error) in
            guard let validationError = error as? CompactBlockValidationError else {
                print("Warning: validateChain operation returning generic error: \(error)")
                return
            }
            
            switch validationError {
            case .validationFailed(let height):
                print("chain validation at height: \(height)")
            }
        }
        
        validateChainOperation.startedHandler = {
            self.state = .validating
        }
        
        validateChainOperation.addDependency(downloadBlockOperation)
        
        let scanBlocksOperation = CompactBlockScanningOperation(rustWelding: self.rustBackend, cacheDb: cfg.cacheDb, dataDb: cfg.dataDb)
        
        scanBlocksOperation.startedHandler = {
            self.state = .scanning
        }
        
        scanBlocksOperation.completionHandler = { (finished, cancelled) in
            guard !cancelled else {
                    print("Warning: operation cancelled")
                return
            }
            self.processBatchFinished(range: range)
        }
        
        scanBlocksOperation.errorHandler = { (error) in
            self.processingError = error
            self.fail(error)
        }
        
        scanBlocksOperation.addDependency(downloadBlockOperation)
        scanBlocksOperation.addDependency(validateChainOperation)
        queue.addOperations([downloadBlockOperation, validateChainOperation, scanBlocksOperation], waitUntilFinished: false)
        
    }
    
    private func processBatchFinished(range: CompactBlockRange) {
        
        guard processingError == nil else {
            retryProcessing(range: range)
            return
        }
        retryAttempts = 0
        guard !range.isEmpty else {
            processingFinished()
            return
        }
        
        do {
            try nextBatch()
        } catch {
            fail(error)
        }
    }
    
    private func processingFinished() {
        self.state = .synced
        self.backoffTimer = Timer(timeInterval: TimeInterval(self.config.blockPollInterval), repeats: true, block: { _ in
            do {
                try self.start()
            } catch {
                self.fail(error)
            }
        })
    }
    
    func nextBatchBlockRange(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) -> CompactBlockRange {
        
        let lowerBound = latestDownloadedHeight <= config.walletBirthday ? config.walletBirthday : latestDownloadedHeight + 1
        return CompactBlockRange(uncheckedBounds: (lowerBound, min(lowerBound + BlockHeight(config.downloadBatchSize - 1), latestHeight)))
    }
    
    func retryProcessing(range: CompactBlockRange) {
        queue.cancelAllOperations()
        processNewBlocks(range: range)
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
        self.state = .error(error)
    }
    
    private func transitionState(from oldValue: State, to newValue: State) {
        guard oldValue != newValue else {
            return
        }
        
        switch newValue {
        case .downloading:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedDownloading, object: self)
        case .synced:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorIdle, object: self)
        case .error(let err):
            NotificationCenter.default.post(name: Notification.Name.blockProcessorFailed, object: self, userInfo: ["error": err])
        case .scanning:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedScanning, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStopped, object: self)
        case .validating:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedValidating, object: self)
        }
    }
}

extension CompactBlockProcessor.Configuration {
    static var standard: CompactBlockProcessor.Configuration {
        let pathProvider = DefaultResourceProvider()
        return CompactBlockProcessor.Configuration(cacheDb: pathProvider.cacheDbURL, dataDb: pathProvider.dataDbURL)
    }
}

extension CompactBlockProcessor.State: Equatable {
    static func == (lhs: CompactBlockProcessor.State, rhs: CompactBlockProcessor.State) -> Bool {
        switch  lhs {
        case .downloading:
            switch  rhs {
            case .downloading:
                return true
            default:
                return false
            }
        case .synced:
            switch rhs {
            case .synced:
                return true
            default:
                return false
            }
        case .scanning:
            switch rhs {
            case .scanning:
                return true
            default:
                return false
            }
        case .stopped:
            switch rhs {
            case .stopped:
                return true
            default:
                return false
            }
        case .error:
            switch rhs {
            case .error:
                return true
            default:
                return false
            }
        case .validating:
            switch rhs {
            case .validating:
                return true
            default:
                return false
            }
        }
    }
}
