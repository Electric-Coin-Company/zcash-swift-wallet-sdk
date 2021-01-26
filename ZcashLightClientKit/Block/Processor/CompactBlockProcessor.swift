//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
/**
 
 Errors thrown by CompactBlock Processor
 */
public enum CompactBlockProcessorError: Error {
    case invalidConfiguration
    case missingDbPath(path: String)
    case dataDbInitFailed(path: String)
    case connectionError(underlyingError: Error)
    case grpcError(statusCode: Int, message: String)
    case connectionTimeout
    case generalError(message: String)
    case maxAttemptsReached(attempts: Int)
    case unspecifiedError(underlyingError: Error)
    case criticalError
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
    public static let foundTransactions = "CompactBlockProcessorNotificationKey.foundTransactions"
    public static let foundTransactionsRange = "CompactBlockProcessorNotificationKey.foundTransactionsRange"
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
     Notification sent when the compact block processor stop() method is called
     */
    static let blockProcessorStopped = Notification.Name(rawValue: "CompactBlockProcessorStopped")
    
    /**
     Notification sent when the compact block processor presented an error.
     
     Query userInfo object on the key CompactBlockProcessorNotificationKey.error
     */
    static let blockProcessorFailed = Notification.Name(rawValue: "CompactBlockProcessorFailed")
    /**
     Notification sent when the compact block processor has finished syncing the blockchain to latest height
     */
    static let blockProcessorFinished = Notification.Name(rawValue: "CompactBlockProcessorFinished")
    /**
     Notification sent when the compact block processor is doing nothing
     */
    static let blockProcessorIdle = Notification.Name(rawValue: "CompactBlockProcessorIdle")
    /**
     Notification sent when something odd happened. probably going from a state to another state that shouldn't be the next state.
     */
    static let blockProcessorUnknownTransition = Notification.Name(rawValue: "CompactBlockProcessorTransitionUnknown")
    /**
     Notification sent when the compact block processor handled a ReOrg.
     
     Query the userInfo object on the key CompactBlockProcessorNotificationKey.reorgHeight for the height on which the reorg was detected. CompactBlockProcessorNotificationKey.rewindHeight for the height that the processor backed to in order to solve the Reorg
     */
    static let blockProcessorHandledReOrg = Notification.Name(rawValue: "CompactBlockProcessorHandledReOrg")
    
    /**
     Notification sent when the compact block processor enhanced a bunch of transactions
    Query the user info object for CompactBlockProcessorNotificationKey.foundTransactions which will contain an [ConfirmedTransactionEntity] Array with the found transactions and CompactBlockProcessorNotificationKey.foundTransactionsrange
     */
    static let blockProcessorFoundTransactions = Notification.Name(rawValue: "CompactBlockProcessorFoundTransactions")
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
        public var network: Network
        private(set) var saplingActivation: BlockHeight
        
        init (
               cacheDb: URL,
               dataDb: URL,
               downloadBatchSize: Int,
               retries: Int,
               maxBackoffInterval: TimeInterval,
               rewindDistance: Int,
               walletBirthday: BlockHeight,
               saplingActivation: BlockHeight,
               network: Network
           ) {
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.downloadBatchSize = downloadBatchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.walletBirthday = walletBirthday
            self.network = network
            self.saplingActivation = saplingActivation
        }
        
        public init(cacheDb: URL, dataDb: URL, walletBirthday: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT, network: Network){
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.walletBirthday = walletBirthday
            self.saplingActivation = ZcashSDK.SAPLING_ACTIVATION_HEIGHT
            self.network = network
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
         Processor is up to date with the blockchain and you can now make transactions.
         */
        case synced
        
    }
    
    public private(set) var state: State = .stopped {
        didSet {
            transitionState(from: oldValue, to: self.state)
        }
    }
    
    private var downloader: CompactBlockDownloading
    private var transactionRepository: TransactionRepository
    private var rustBackend: ZcashRustBackendWelding.Type
    private var config: Configuration = Configuration.standard
    private var queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "CompactBlockProcessorQueue"
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
    public convenience init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration) {
        self.init(downloader: downloader,
                  backend: backend,
                  config: config,
                  repository: TransactionRepositoryBuilder.build(dataDbURL: config.dataDb))
    }
    
    /**
    Initializes a CompactBlockProcessor instance from an Initialized object
    - Parameters:
     - initializer: an instance that complies to CompactBlockDownloading protocol
     - configuration: configuration for this compact block processor
    */
    public convenience init(initializer: Initializer, configuration: Configuration = Configuration.standard) {
        self.init(downloader: initializer.downloader,
                  backend: initializer.rustBackend,
                  config: configuration,
                  repository: initializer.transactionRepository)
    }
    
    internal init(downloader: CompactBlockDownloading, backend: ZcashRustBackendWelding.Type, config: Configuration, repository: TransactionRepository) {
        self.downloader = downloader
        self.rustBackend = backend
        self.config = config
        self.transactionRepository = repository
        self.latestBlockHeight = config.walletBirthday
    }
    
    deinit {
        self.queue.cancelAllOperations()
    }
    
    var maxAttemptsReached: Bool {
        self.retryAttempts < self.config.retries
    }
    var shouldStart: Bool {
        switch self.state {
        case .stopped, .synced, .error:
            return maxAttemptsReached
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
    public func start(retry: Bool = false) throws {
        
        // TODO: check if this validation makes sense at all
        //        try validateConfiguration()
        if retry {
            self.retryAttempts = 0
            self.processingError = nil
        }
        guard !queue.isSuspended else {
            queue.isSuspended = false
            return
        }
        
        guard shouldStart else {
            switch self.state {
            case .error(let e):
                // max attempts have been reached
                LoggerProxy.info("max retry attempts reached with error: \(e)")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
                self.state = .stopped
            case .stopped:
                // max attempts have been reached
                LoggerProxy.info("max retry attempts reached")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
            case .synced:
                // max attempts have been reached
                LoggerProxy.warn("max retry attempts reached on synced state, this indicates malfunction")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
            default:
                LoggerProxy.debug("Warning: compact block processor was started while busy!!!!")
            }
            return
        }
        
        let birthday = WalletBirthday.birthday(with: config.walletBirthday, network: config.network)
        
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
                        } else if self.latestBlockHeight < latestDownloadedBlockHeight {
                            // Lightwalletd might be syncing
                            LoggerProxy.info("Lightwalletd might be syncing: latest downloaded block height is: \(latestDownloadedBlockHeight) while latest blockheight is reported at: \(blockHeight)")
                            self.processingFinished(height: latestDownloadedBlockHeight)
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
    /**
     processes new blocks on the given range based on the configuration set for this instance
     the way operations are queued is implemented based on the following good practice https://forums.developer.apple.com/thread/25761
     
     */
    func processNewBlocks(range: CompactBlockRange) {
        
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil
        
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
        
        let downloadValidateAdapterOperation = BlockOperation { [weak validateChainOperation, weak downloadBlockOperation] in

            validateChainOperation?.error = downloadBlockOperation?.error
        }
        
        validateChainOperation.completionHandler = { [weak self] (finished, cancelled) in
            guard !cancelled else {
                self?.state = .stopped
                LoggerProxy.debug("Warning: validateChainOperation operation cancelled")
                return
            }
            
            LoggerProxy.debug("validateChainFinished")
        }
        
        validateChainOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }

            guard let validationError = error as? CompactBlockValidationError else {
                LoggerProxy.error("Warning: validateChain operation returning generic error: \(error)")
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
        
        let scanBlocksOperation = CompactBlockScanningOperation(rustWelding: self.rustBackend, cacheDb: cfg.cacheDb, dataDb: cfg.dataDb)
        
        let validateScanningAdapterOperation = BlockOperation { [weak scanBlocksOperation, weak validateChainOperation] in
            scanBlocksOperation?.error = validateChainOperation?.error
        }
        scanBlocksOperation.startedHandler = { [weak self] in
            self?.state = .scanning
        }
        
        scanBlocksOperation.completionHandler = { [weak self] (finished, cancelled) in
            guard !cancelled else {
                self?.state = .stopped
                LoggerProxy.debug("Warning: scanBlocksOperation operation cancelled")
                return
            }
        }
        
        scanBlocksOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
            
            self.processingError = error
            self.fail(error)
        }
        
        let enhanceOperation = CompactBlockEnhancementOperation(rustWelding: rustBackend, dataDb: config.dataDb, downloader: downloader, repository: transactionRepository, range: range.blockRange())
        
        enhanceOperation.startedHandler = {
            LoggerProxy.debug("Started Enhancing range: \(range)")
        }
        
        enhanceOperation.txFoundHandler = { [weak self] (txs,range) in
            self?.notifyTransactions(txs,in: range)
        }
        
        enhanceOperation.completionHandler  = { [weak self] (finished, cancelled) in
            guard !cancelled else {
                self?.state = .stopped
                LoggerProxy.debug("Warning: enhance operation on range \(range) cancelled")
                return
            }
            self?.processBatchFinished(range: range)
        }
        
        enhanceOperation.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
            
            self.processingError = error
            self.fail(error)
        }
        
        let scanEnhanceAdapterOperation = BlockOperation { [weak enhanceOperation, weak scanBlocksOperation] in
            enhanceOperation?.error = scanBlocksOperation?.error
        }
        
        downloadValidateAdapterOperation.addDependency(downloadBlockOperation)
        validateChainOperation.addDependency(downloadValidateAdapterOperation)
        scanBlocksOperation.addDependency(validateScanningAdapterOperation)
        scanEnhanceAdapterOperation.addDependency(scanBlocksOperation)
        enhanceOperation.addDependency(scanEnhanceAdapterOperation)
        
        queue.addOperations([downloadBlockOperation,
                             downloadValidateAdapterOperation,
                             validateChainOperation,
                             validateScanningAdapterOperation,
                             scanBlocksOperation,
                             scanEnhanceAdapterOperation,
                             enhanceOperation], waitUntilFinished: false)
        
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
    
    func notifyTransactions(_ txs: [ConfirmedTransactionEntity], in range: BlockRange) {
        NotificationCenter.default.post(name: .blockProcessorFoundTransactions,
                                        object: self,
                                        userInfo: [ CompactBlockProcessorNotificationKey.foundTransactions : txs,
                                                    CompactBlockProcessorNotificationKey.foundTransactionsRange : ClosedRange(uncheckedBounds: (range.start.height,range.end.height))
                                        ])
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
        setTimer()
    }
    
    private func setTimer() {
        let interval = self.config.blockPollInterval
        self.backoffTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true, block: { [weak self] _ in
            
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                do {
                    if self.shouldStart {
                        try self.start()
                    } else if self.maxAttemptsReached {
                        self.fail(CompactBlockProcessorError.maxAttemptsReached(attempts: self.config.retries))
                    }
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
        self.processingError = nil
        guard self.retryAttempts < config.retries else {
            self.notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.retryAttempts))
            self.stop()
            return
        }
        
        do {
            try downloader.rewind(to: max(range.lowerBound, self.config.walletBirthday))
            
            // process next batch
            processNewBlocks(range: self.nextBatchBlockRange(latestHeight: latestBlockHeight, latestDownloadedHeight: try downloader.lastDownloadedBlockHeight()))
        } catch {
            self.fail(error)
        }
        
    }
    
    func fail(_ error: Error) {
        // todo specify: failure
        LoggerProxy.error("\(error)")
        queue.cancelAllOperations()
        self.retryAttempts = self.retryAttempts + 1
        self.processingError = error
        switch self.state {
        case .error:
            notifyError(error)
        default:
            break
        }
        self.state = .error(error)
        self.setTimer()
        
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
            notifyError(err)
        case .scanning:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedScanning, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStopped, object: self)
        case .validating:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedValidating, object: self)
        }
    }
    private func notifyError(_ err: Error) {
        NotificationCenter.default.post(name: Notification.Name.blockProcessorFailed, object: self, userInfo: [CompactBlockProcessorNotificationKey.error: mapError(err)])
    }
    // TODO: encapsulate service errors better
    func mapError(_ error: Error) -> CompactBlockProcessorError {
        if let processorError = error as? CompactBlockProcessorError {
            return processorError
        }
        if let lwdError = error as? LightWalletServiceError {
            return lwdError.mapToProcessorError()
        } else if let rpcError = error as? GRPC.GRPCStatus {
            switch rpcError {
            case .ok:
                let msg = "Error Raised when status is OK"
                LoggerProxy.warn(msg)
                return CompactBlockProcessorError.grpcError(statusCode: rpcError.code.rawValue, message: rpcError.message ?? "Error Raised when status is OK")
            default:
                return CompactBlockProcessorError.grpcError(statusCode: rpcError.code.rawValue, message: rpcError.message ?? "No message")
                
            }
        }
        return .unspecifiedError(underlyingError: error)
    }
}

public extension CompactBlockProcessor.Configuration {
    /**
     Standard configuration for most compact block processors
     */
    static var standard: CompactBlockProcessor.Configuration {
        let pathProvider = DefaultResourceProvider()
        return CompactBlockProcessor.Configuration(cacheDb: pathProvider.cacheDbURL, dataDb: pathProvider.dataDbURL, network: "ZEC")
    }
}

extension LightWalletServiceError {
    func mapToProcessorError() -> CompactBlockProcessorError {
        switch self {
        case .failed(let statusCode, let message):
            return CompactBlockProcessorError.grpcError(statusCode: statusCode, message: message)
        case .invalidBlock:
            return CompactBlockProcessorError.generalError(message: "\(self)")
        case .generalError(let message):
            return CompactBlockProcessorError.generalError(message: message)
        case .sentFailed(let error):
            return CompactBlockProcessorError.connectionError(underlyingError: error)
        case .genericError(let error):
            return CompactBlockProcessorError.unspecifiedError(underlyingError: error)
        case .timeOut:
            return CompactBlockProcessorError.connectionTimeout
        case .criticalError:
            return CompactBlockProcessorError.criticalError
        case .userCancelled:
            return CompactBlockProcessorError.connectionTimeout
        case .unknown:
            return CompactBlockProcessorError.unspecifiedError(underlyingError: self)
        }
    }
}
extension CompactBlockProcessor.State: Equatable {
    public static func == (lhs: CompactBlockProcessor.State, rhs: CompactBlockProcessor.State) -> Bool {
        switch  (lhs, rhs) {
        case (.downloading, .downloading),
             (.scanning, .scanning),
             (.validating, .validating),
             (.stopped, .stopped),
             (.error, .error),
             (.synced, .synced): return true
        default: return false
        }
    }
}
