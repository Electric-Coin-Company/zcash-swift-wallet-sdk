//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public enum CompactBlockProcessorError: Error {
    case invalidConfiguration
    case missingDbPath(path: String)
    case dataDbInitFailed(path: String)
}

public struct CompactBlockProcessorNotificationKey {
    public static let progress = "CompactBlockProcessorNotificationKey.progress"
    public static let progressHeight = "CompactBlockProcessorNotificationKey.progressHeight"
    public static let reorgHeight = "CompactBlockProcessorNotificationKey.reorgHeight"
    public static let latestScannedBlockHeight = "CompactBlockProcessorNotificationKey.latestScannedBlockHeight"
}

public extension Notification.Name {
    /**
     Processing progress update. usertInfo["progress"]
     */
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    static let blockProcessorStartedDownloading = Notification.Name(rawValue: "CompactBlockProcessorStartedDownloading")
    static let blockProcessorStartedValidating = Notification.Name(rawValue: "CompactBlockProcessorStartedValidating")
    static let blockProcessorStartedScanning = Notification.Name(rawValue: "CompactBlockProcessorStartedScanning")
    static let blockProcessorStopped = Notification.Name(rawValue: "CompactBlockProcessorStopped")
    static let blockProcessorFailed = Notification.Name(rawValue: "CompactBlockProcessorFailed")
    static let blockProcessorFinished = Notification.Name(rawValue: "CompactBlockProcessorFinished")
    static let blockProcessorIdle = Notification.Name(rawValue: "CompactBlockProcessorIdle")
    static let blockProcessorUnknownTransition = Notification.Name(rawValue: "CompactBlockProcessorTransitionUnknown")
    static let blockProcessorHandledReOrg = Notification.Name(rawValue: "CompactBlockProcessorHandledReOrg")
}

public class CompactBlockProcessor {
    /**
     Compact Block Processor configuration
     
     Property: cacheDbPath absolute file path of the DB where raw, unprocessed compact blocks are stored.
     Property: dataDbPath absolute file path of the DB where all information derived from the cache DB is stored.
     */
    
    // TODO: make internal again
    public struct Configuration {
        public var cacheDb: URL
        public var dataDb: URL
        public var downloadBatchSize = DEFAULT_BATCH_SIZE
        public var blockPollInterval = DEFAULT_POLL_INTERVAL
        public var retries = DEFAULT_RETRIES
        public var maxBackoffInterval = DEFAULT_MAX_BACKOFF_INTERVAL
        public var rewindDistance = DEFAULT_REWIND_DISTANCE
        public var walletBirthday: BlockHeight
        
        public init(cacheDb: URL, dataDb: URL, walletBirthday: BlockHeight = SAPLING_ACTIVATION_HEIGHT){
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.walletBirthday = walletBirthday
        }
    }
    
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
    
    public init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
        self.latestBlockHeight = config.walletBirthday
    }
    
    deinit {
        self.queue.cancelAllOperations()
    }
    
    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.cacheDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.cacheDb.absoluteString)
        }
        
        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDb.absoluteString)
        }
    }
    
    public func start() throws {
        
        // TODO: check if this validation makes sense at all
        //        try validateConfiguration()
        
        guard !queue.isSuspended else {
            queue.isSuspended = false
            return
        }
        
        guard let birthday = WalletBirthday.birthday(with: config.walletBirthday) else {
            throw CompactBlockProcessorError.invalidConfiguration
        }
        
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
            self.downloader.latestBlockHeight { (result) in
                switch result {
                case .success(let blockHeight):
                    self.latestBlockHeight = blockHeight
                    
                    if self.latestBlockHeight == latestDownloadedBlockHeight  {
                        self.processingFinished(height: blockHeight)
                    } else {
                        self.processNewBlocks(range: self.nextBatchBlockRange(latestHeight: self.latestBlockHeight, latestDownloadedHeight: latestDownloadedBlockHeight))
                    }
                case .failure(let e):
                    DispatchQueue.main.async {
                        self.fail(e)
                    }
                }
            }
        }
    }
    
    func processNewBlocks(range: CompactBlockRange) {
//        guard !range.isEmpty else {
//            processingFinished(height: range.upperBound)
//            return
//        }
        
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
                self.validationFailed(at: height)
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
            print("scan operation completed: \(scanBlocksOperation)")
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
    
    func calculateProgress(start: BlockHeight, current: BlockHeight, latest: BlockHeight) -> Float {
        let totalBlocks = Float(abs(latest - start))
        let completed = Float(abs(current - start))
        let progress = completed / totalBlocks
        return progress
    }
    
    func notifyProgress(completedRange: CompactBlockRange) {
        let progress = calculateProgress(start: self.lowerBoundHeight ?? config.walletBirthday, current: completedRange.upperBound, latest: self.latestBlockHeight)
        
        print("\(self) progress: \(progress)")
        NotificationCenter.default.post(name: Notification.Name.blockProcessorUpdated,
                                        object: self,
                                        userInfo: [ CompactBlockProcessorNotificationKey.progress : progress ])
    }
    
    private func validationFailed(at height: BlockHeight) {
        
        // cancel all Tasks
        queue.cancelAllOperations()
        
        // notify reorg
        NotificationCenter.default.post(name: Notification.Name.blockProcessorHandledReOrg, object: self, userInfo: [CompactBlockProcessorNotificationKey.reorgHeight : height])
        
        // register latest failure
        self.lastChainValidationFailure = height
        self.consecutiveChainValidationErrors = self.consecutiveChainValidationErrors + 1
        
        // rewind
        
        let rewindHeight = determineLowerBound(errorHeight: height)
        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: Int32(rewindHeight)) else {
            fail(rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)"))
            return
        }
        
        do {
            try downloader.rewind(to: rewindHeight)
            // process next batch
            processNewBlocks(range: self.nextBatchBlockRange(latestHeight: latestBlockHeight, latestDownloadedHeight: try downloader.lastDownloadedBlockHeight()))
        } catch {
            self.fail(error)
        }
    }
    
    func determineLowerBound(errorHeight: Int) -> BlockHeight {
        let offset = min(MAX_REORG_SIZE, DEFAULT_REWIND_DISTANCE * (consecutiveChainValidationErrors + 1))
        return max(errorHeight - offset, lowerBoundHeight ?? SAPLING_ACTIVATION_HEIGHT)
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
        print(error)
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

public extension CompactBlockProcessor.Configuration {
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
