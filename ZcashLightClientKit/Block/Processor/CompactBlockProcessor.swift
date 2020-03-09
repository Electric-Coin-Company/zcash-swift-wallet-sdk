//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
/**
 Errors thrown by CompactBlock Processor
 */
public enum CompactBlockProcessorError: Error {
    case invalidConfiguration
    case missingDbPath(path: String)
    case dataDbInitFailed(path: String)
}
/**
 CompactBlockProcessor notification userInfo object keys.
 check Notification.Name extensions for more details.
 */
public struct CompactBlockProcessorNotificationKey {
    public static let progress = "CompactBlockProcessorNotificationKey.progress"
    public static let progressHeight = "CompactBlockProcessorNotificationKey.progressHeight"
    public static let reorgHeight = "CompactBlockProcessorNotificationKey.reorgHeight"
    public static let latestScannedBlockHeight = "CompactBlockProcessorNotificationKey.latestScannedBlockHeight"
    public static let rewindHeight = "CompactBlockProcessorNotificationKey.rewindHeight"
    public static let error = "error"
}

public extension Notification.Name {
    /**
     Processing progress update
     
     Query the userInfo object for the key CompactBlockProcessorNotificationKey.progress and CompactBlockProcessorNotificationKey.progressheight for more information on progress % and height
     */
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    
    /**
     Notification sent when a compact block processor starts downloading
     */
    static let blockProcessorStartedDownloading = Notification.Name(rawValue: "CompactBlockProcessorStartedDownloading")
    /**
     Notification sent when the compact block processor starts validating the chain state
     */
    static let blockProcessorStartedValidating = Notification.Name(rawValue: "CompactBlockProcessorStartedValidating")
    /**
     Notification sent when the compact block processor starts scanning blocks from the cache
     */
    static let blockProcessorStartedScanning = Notification.Name(rawValue: "CompactBlockProcessorStartedScanning")
    
    /**
     Notification sent when the compact block processsor stop() method is called
     */
    static let blockProcessorStopped = Notification.Name(rawValue: "CompactBlockProcessorStopped")
    
    /**
    Notification sent when the compact block processsor presented an error.
     
     Query userInfo object on the key CompactBlockProcessorNotificationKey.error
    */
    static let blockProcessorFailed = Notification.Name(rawValue: "CompactBlockProcessorFailed")
    /**
    Notification sent when the compact block processsor has finished syncing the blockchain to latest height
    */
    static let blockProcessorFinished = Notification.Name(rawValue: "CompactBlockProcessorFinished")
    /**
    Notification sent when the compact block processsor is doing nothing
    */
    static let blockProcessorIdle = Notification.Name(rawValue: "CompactBlockProcessorIdle")
    /**
    Notification sent when something odd happened. probably going from a state to another state that shouldn't be the next state.
    */
    static let blockProcessorUnknownTransition = Notification.Name(rawValue: "CompactBlockProcessorTransitionUnknown")
    /**
    Notification sent when the compact block processsor handled a ReOrg.
     
     Query the userInfo object on the key CompactBlockProcessorNotificationKey.reorgHeight for the height on which the reorg was detected. CompactBlockProcessorNotificationKey.rewindHeight for the height that the processor backed to in order to solve the Reorg
    */
    static let blockProcessorHandledReOrg = Notification.Name(rawValue: "CompactBlockProcessorHandledReOrg")
}

/**
 The compact block processor is in charge of orchestrating the download and caching of compact blocks from a LightWalletEndpoint
 when started the processor downloads does a download - validate - scan cycle until it reaches latest height on the blockchain.
 
 */
public class CompactBlockProcessor {
    /**
     Compact Block Processor configuration
     
     Property: cacheDbPath absolute file path of the DB where raw, unprocessed compact blocks are stored.
     Property: dataDbPath absolute file path of the DB where all information derived from the cache DB is stored.
     */
    
    public struct Configuration {
        public var cacheDb: URL
        public var dataDb: URL
        public var downloadBatchSize = ZcashSDK.DEFAULT_BATCH_SIZE
        public var blockPollInterval: TimeInterval {
            TimeInterval.random(in: ZcashSDK.DEFAULT_POLL_INTERVAL / 2 ... ZcashSDK.DEFAULT_POLL_INTERVAL * 1.5)
        }
        
        public var retries = ZcashSDK.DEFAULT_RETRIES
        public var maxBackoffInterval = ZcashSDK.DEFAULT_MAX_BACKOFF_INTERVAL
        public var rewindDistance = ZcashSDK.DEFAULT_REWIND_DISTANCE
        public var walletBirthday: BlockHeight
        
        public init(cacheDb: URL, dataDb: URL, walletBirthday: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT){
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.walletBirthday = walletBirthday
        }
    }
    /**
     Represents the possible states of a CompactBlockProcessor
     */
    public enum State {
        
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
    
    public private(set) var state: State = .stopped {
        didSet {
            transitionState(from: oldValue, to: self.state)
        }
    }
    
    private var downloader: CompactBlockDownloading
    private var rustBackend: ZcashRustBackendWelding.Type
    private var config: Configuration = Configuration.standard
    private var queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    } ()
    
    private var retryAttempts: Int = 0
    private var backoffTimer: Timer?
    private var lowerBoundHeight: BlockHeight?
    private var latestBlockHeight: BlockHeight
    private var lastChainValidationFailure: BlockHeight?
    private var consecutiveChainValidationErrors: Int = 0
    private var processingError: Error?
    
    private var maxAttempts: Int {
        config.retries
    }
    
    private var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }
    
    /**
     Initializes a CompactBlockProcessor instance
     - Parameters:
        - downloader: an instance that complies to CompactBlockDownloading protocol
        - backend: a class that complies to ZcashRustBackendWelding
     */
    public init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
        self.latestBlockHeight = config.walletBirthday
    }
    
    deinit {
        self.queue.cancelAllOperations()
    }
    
    
    var shouldStart: Bool {
        switch self.state {
        case .stopped, .synced, .error(_):
            return self.retryAttempts < self.config.retries
        default:
            return false
        }
    }
    
    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.cacheDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.cacheDb.absoluteString)
        }
        
        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDb.absoluteString)
        }
    }
    /**
     Starts the CompactBlockProcessor instance and starts downloading and processing blocks
     
     triggers the blockProcessorStartedDownloading notification
     
     - Important: subscribe to the notifications before calling this method
     
     */
    public func start() throws {
        
        // TODO: check if this validation makes sense at all
        //        try validateConfiguration()
        
        guard !queue.isSuspended else {
            queue.isSuspended = false
            return
        }
        
        guard shouldStart else {
            LoggerProxy.debug("Warning: compact block processor was started while busy!!!!")
            return
        }
        
        let birthday = WalletBirthday.birthday(with: config.walletBirthday)
        
        do {
            try rustBackend.initDataDb(dbData: config.dataDb)
            try rustBackend.initBlocksTable(dbData: config.dataDb, height: Int32(birthday.height), hash: birthday.hash, time: birthday.time, saplingTree: birthday.tree)
        } catch RustWeldingError.dataDbNotEmpty {
            // i'm ok
        } catch {
            throw CompactBlockProcessorError.dataDbInitFailed(path: config.dataDb.absoluteString)
        }
        
        try nextBatch()
        
    }
    
    
    /**
     Stops the CompactBlockProcessor
     
     Note: retry count is reset
     - Parameter cancelTasks: cancel the pending tasks. Defaults to true
     */
    public func stop(cancelTasks: Bool = true) {
           self.backoffTimer?.invalidate()
           self.backoffTimer = nil
           if cancelTasks {
               queue.cancelAllOperations()
           } else {
               self.queue.isSuspended = true
           }
        self.retryAttempts = 0
           self.state = .stopped
    }
    
    private func nextBatch() throws {
        // get latest block height
        
        let latestDownloadedBlockHeight: BlockHeight = max(config.walletBirthday,try downloader.lastDownloadedBlockHeight())
        
        if self.lowerBoundHeight == nil {
            self.lowerBoundHeight = latestDownloadedBlockHeight
        }
        // get latest block height from lightwalletd
        
        if self.latestBlockHeight > latestDownloadedBlockHeight {
            self.processNewBlocks(range: self.nextBatchBlockRange(latestHeight: self.latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight))
        } else {
            self.downloader.latestBlockHeight { [weak self] (result) in
                guard let self = self else { return }
                switch result {
                case .success(let blockHeight):
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.latestBlockHeight = blockHeight
                        
                        if self.latestBlockHeight == latestDownloadedBlockHeight  {
                            self.processingFinished(height: blockHeight)
                        } else {
                            self.processNewBlocks(range: self.nextBatchBlockRange(latestHeight: self.latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight))
                        }
                    }
                case .failure(let e):
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.fail(e)
                    }
                }
            }
        }
    }
    
    func processNewBlocks(range: CompactBlockRange) {
        
        let cfg = self.config
        
        let downloadBlockOperation = CompactBlockDownloadOperation(downloader: self.downloader, range: range)
        
        downloadBlockOperation.startedHandler = { [weak self] in
         
                self?.state = .downloading
            
        }
        
        downloadBlockOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
          
                self.processingError = error
                self.fail(error)
           
        }
        
        let validateChainOperation = CompactBlockValidationOperation(rustWelding: self.rustBackend, cacheDb: cfg.cacheDb, dataDb: cfg.dataDb)
        
        validateChainOperation.completionHandler = { (finished, cancelled) in
            guard !cancelled else {
                LoggerProxy.debug("Warning: operation cancelled")
                return
            }
            
            LoggerProxy.debug("validateChainFinished")
        }
        
        validateChainOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
           
                guard let validationError = error as? CompactBlockValidationError else {
                    LoggerProxy.debug("Warning: validateChain operation returning generic error: \(error)")
                    return
                }
                
                switch validationError {
                case .validationFailed(let height):
                    LoggerProxy.debug("chain validation at height: \(height)")
                    self.validationFailed(at: height)
                }
            
        }
        
        validateChainOperation.startedHandler = { [weak self] in
            
                self?.state = .validating
            
        }
        
        validateChainOperation.addDependency(downloadBlockOperation)
        
        let scanBlocksOperation = CompactBlockScanningOperation(rustWelding: self.rustBackend, cacheDb: cfg.cacheDb, dataDb: cfg.dataDb)
        
        scanBlocksOperation.startedHandler = { [weak self] in
                self?.state = .scanning
        }
        
        
        scanBlocksOperation.completionHandler = { [weak self] (finished, cancelled) in
            guard !cancelled else {
                LoggerProxy.debug("Warning: operation cancelled")
                return
            }
                self?.processBatchFinished(range: range)
        }
        
        scanBlocksOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }

                self.processingError = error
                self.fail(error)
            
        }
        
        scanBlocksOperation.addDependency(downloadBlockOperation)
        scanBlocksOperation.addDependency(validateChainOperation)
        queue.addOperations([downloadBlockOperation, validateChainOperation, scanBlocksOperation], waitUntilFinished: false)
        
    }
    
    func calculateProgress(start: BlockHeight, current: BlockHeight, latest: BlockHeight) -> Float {
        let totalBlocks = Float(abs(latest - start))
        let completed = Float(abs(current - start))
        let progress = completed / totalBlocks
        return progress
    }
    
    func notifyProgress(completedRange: CompactBlockRange) {
        let progress = calculateProgress(start: self.lowerBoundHeight ?? config.walletBirthday, current: completedRange.upperBound, latest: self.latestBlockHeight)
        
        LoggerProxy.debug("\(self) progress: \(progress)")
        NotificationCenter.default.post(name: Notification.Name.blockProcessorUpdated,
                                        object: self,
                                        userInfo: [ CompactBlockProcessorNotificationKey.progress : progress,
                                                    CompactBlockProcessorNotificationKey.progressHeight : self.latestBlockHeight])
    }
    
    private func validationFailed(at height: BlockHeight) {
        
        // cancel all Tasks
        queue.cancelAllOperations()
        
        // register latest failure
        self.lastChainValidationFailure = height
        self.consecutiveChainValidationErrors = self.consecutiveChainValidationErrors + 1
        
        // rewind
        
        let rewindHeight = determineLowerBound(errorHeight: height, consecutiveErrors: consecutiveChainValidationErrors, walletBirthday: self.config.walletBirthday)
        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: Int32(rewindHeight)) else {
            fail(rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)"))
            return
        }
        
        do {
            try downloader.rewind(to: rewindHeight)
            
            // notify reorg
            NotificationCenter.default.post(name: Notification.Name.blockProcessorHandledReOrg, object: self, userInfo: [CompactBlockProcessorNotificationKey.reorgHeight : height, CompactBlockProcessorNotificationKey.rewindHeight : rewindHeight])
                    
            // process next batch
            processNewBlocks(range: self.nextBatchBlockRange(latestHeight: latestBlockHeight, latestDownloadedHeight: try downloader.lastDownloadedBlockHeight()))
        } catch {
            self.fail(error)
        }
    }
    
    func determineLowerBound(errorHeight: Int, consecutiveErrors: Int, walletBirthday: BlockHeight) -> BlockHeight {
            let offset = min(ZcashSDK.MAX_REORG_SIZE, ZcashSDK.DEFAULT_REWIND_DISTANCE * (consecutiveErrors + 1))
            return max(errorHeight - offset, walletBirthday - ZcashSDK.MAX_REORG_SIZE)
    }
        
    private func processBatchFinished(range: CompactBlockRange) {
        
        guard processingError == nil else {
            retryProcessing(range: range)
            return
        }
        
        retryAttempts = 0
        consecutiveChainValidationErrors = 0
        
        notifyProgress(completedRange: range)
        
        guard !range.isEmpty else {
            processingFinished(height: range.upperBound)
            return
        }
        
        do {
            try nextBatch()
        } catch {
            fail(error)
        }
    }
    
    private func processingFinished(height: BlockHeight) {
        self.state = .synced
        NotificationCenter.default.post(name: Notification.Name.blockProcessorFinished, object: self, userInfo: [CompactBlockProcessorNotificationKey.latestScannedBlockHeight : height])
        let interval = self.config.blockPollInterval
        self.backoffTimer?.invalidate() 
        let timer = Timer(timeInterval: interval, repeats: true, block: { [weak self] _ in
            
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                    do {
                    try self.start()
                } catch {
                    self.fail(error)
                }
            }
        })
        RunLoop.main.add(timer, forMode: .default)
        
        self.backoffTimer = timer
    }
    
    func nextBatchBlockRange(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight) -> CompactBlockRange {
        
        let lowerBound = latestDownloadedHeight <= config.walletBirthday ? config.walletBirthday : latestDownloadedHeight + 1
        
        let upperBound = BlockHeight(min(lowerBound + BlockHeight(config.downloadBatchSize - 1), latestHeight))
        return lowerBound ... upperBound
    }
    
    func retryProcessing(range: CompactBlockRange) {
        
        queue.cancelAllOperations()
        // update retries
        self.retryAttempts = self.retryAttempts + 1
        guard self.retryAttempts < config.retries else {
            self.stop()
            return
        }
        
        processNewBlocks(range: range)
    }
    
    func fail(_ error: Error) {
        // todo specify: failure
        LoggerProxy.error("\(error)")
        queue.cancelAllOperations()
        self.retryAttempts = self.retryAttempts + 1
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
            NotificationCenter.default.post(name: Notification.Name.blockProcessorFailed, object: self, userInfo: [CompactBlockProcessorNotificationKey.error: err])
        case .scanning:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedScanning, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStopped, object: self)
        case .validating:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedValidating, object: self)
        }
    }
}

public extension CompactBlockProcessor.Configuration {
    /**
    Standard configuration for most compact block processors
    */
    static var standard: CompactBlockProcessor.Configuration {
        let pathProvider = DefaultResourceProvider()
        return CompactBlockProcessor.Configuration(cacheDb: pathProvider.cacheDbURL, dataDb: pathProvider.dataDbURL)
    }
}

extension CompactBlockProcessor.State: Equatable {
    public static func == (lhs: CompactBlockProcessor.State, rhs: CompactBlockProcessor.State) -> Bool {
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
