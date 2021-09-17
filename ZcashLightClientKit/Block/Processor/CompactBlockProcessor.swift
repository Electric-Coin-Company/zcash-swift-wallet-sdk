//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
// swiftlint:disable file_length type_body_length

import Foundation
import GRPC

public typealias RefreshedUTXOs = (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])

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
    case invalidAccount
    case wrongConsensusBranchId(expectedLocally: ConsensusBranchID, found: ConsensusBranchID)
    case networkMismatch(expected: NetworkType, found: NetworkType)
    case saplingActivationMismatch(expected: BlockHeight, found: BlockHeight)
}

/**
CompactBlockProcessor notification userInfo object keys.
check Notification.Name extensions for more details.
*/
public enum CompactBlockProcessorNotificationKey {
    public static let progress = "CompactBlockProcessorNotificationKey.progress"
    // public static let progressStartHeight = "CompactBlockProcessorNotificationKey.progressStartHeight"
    // public static let progressTargetHeight = "CompactBlockProcessorNotificationKey.progressTargetHeight"
    public static let progressBlockTime = "CompactBlockProcessorNotificationKey.progressBlockTime"
    public static let reorgHeight = "CompactBlockProcessorNotificationKey.reorgHeight"
    public static let latestScannedBlockHeight = "CompactBlockProcessorNotificationKey.latestScannedBlockHeight"
    public static let rewindHeight = "CompactBlockProcessorNotificationKey.rewindHeight"
    public static let foundTransactions = "CompactBlockProcessorNotificationKey.foundTransactions"
    public static let foundBlocks = "CompactBlockProcessorNotificationKey.foundBlocks"
    public static let foundTransactionsRange = "CompactBlockProcessorNotificationKey.foundTransactionsRange"
    public static let error = "error"
    public static let refreshedUTXOs = "CompactBlockProcessorNotificationKey.refreshedUTXOs"
    public static let enhancementProgress = "CompactBlockProcessorNotificationKey.enhancementProgress"
    public static let previousStatus = "CompactBlockProcessorNotificationKey.previousStatus"
    public static let newStatus = "CompactBlockProcessorNotificationKey.newStatus"
    public static let currentConnectivityStatus = "CompactBlockProcessorNotificationKey.currentConnectivityStatus"
    public static let previousConnectivityStatus = "CompactBlockProcessorNotificationKey.previousConnectivityStatus"
}

public enum CompactBlockProgress {
    case download(_ progress: BlockProgress)
    case validate
    case scan(_ progress: BlockProgress)
    case enhance(_ progress: EnhancementStreamProgress)
    case fetch
    
    public var progress: Float {
        switch self {
        case .download(let blockProgress), .scan(let blockProgress):
            return blockProgress.progress
        case .enhance(let enhancementProgress):
            return enhancementProgress.progress
        default:
            return 0
        }
    }
    
    public var progressHeight: BlockHeight? {
        switch self {
        case .download(let blockProgress), .scan(let blockProgress):
            return blockProgress.progressHeight
        case .enhance(let enhancementProgress):
            return enhancementProgress.lastFoundTransaction?.minedHeight
        default:
            return 0
        }
    }
    
    public var blockDate: Date? {
        if case .enhance(let enhancementProgress) = self, let time = enhancementProgress.lastFoundTransaction?.blockTimeInSeconds {
            return Date(timeIntervalSince1970: time)
        }
        
        return nil
    }
    
    public var targetHeight: BlockHeight? {
        switch self {
        case .download(let blockProgress), .scan(let blockProgress):
            return blockProgress.targetHeight
        default:
            return nil
        }
    }
}

protocol EnhancementStreamDelegate: AnyObject {
    func transactionEnhancementProgressUpdated(_ progress: EnhancementProgress)
}

public protocol EnhancementProgress {
    var totalTransactions: Int { get }
    var enhancedTransactions: Int { get }
    var lastFoundTransaction: ConfirmedTransactionEntity? { get }
    var range: CompactBlockRange { get }
}

public struct EnhancementStreamProgress: EnhancementProgress {
    public var totalTransactions: Int
    public var enhancedTransactions: Int
    public var lastFoundTransaction: ConfirmedTransactionEntity?
    public var range: CompactBlockRange
    
    public var progress: Float {
        totalTransactions > 0 ? Float(enhancedTransactions) / Float(totalTransactions) : 0
    }
}

public extension Notification.Name {
    /**
    Processing progress update
     
    Query the userInfo object for the key CompactBlockProcessorNotificationKey.progress for a CompactBlockProgress struct
    */
    static let blockProcessorUpdated = Notification.Name(rawValue: "CompactBlockProcessorUpdated")
    
    /**
    notification sent when processor status changed
    */
    static let blockProcessorStatusChanged = Notification.Name(rawValue: "CompactBlockProcessorStatusChanged")

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
    
    /**
    Notification sent when the compact block processor fetched utxos from lightwalletd attempted to store them
    Query the user info object for CompactBlockProcessorNotificationKey.blockProcessorStoredUTXOs which will contain a RefreshedUTXOs tuple with the collection of UTXOs stored or skipped
    */
    static let blockProcessorStoredUTXOs = Notification.Name(rawValue: "CompactBlockProcessorStoredUTXOs")
    
    static let blockProcessorStartedEnhancing = Notification.Name(rawValue: "CompactBlockProcessorStartedEnhancing")
    
    static let blockProcessorEnhancementProgress = Notification.Name("CompactBlockProcessorEnhancementProgress")
    
    static let blockProcessorStartedFetching = Notification.Name(rawValue: "CompactBlockProcessorStartedFetching")
    
    /**
    Notification sent when the grpc service connection detects a change. Query the user info object  for status change details `currentConnectivityStatus` for current and previous with `previousConnectivityStatus`
    */
    static let blockProcessorConnectivityStateChanged = Notification.Name("CompactBlockProcessorConnectivityStateChanged")
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
        public var downloadBatchSize = ZcashSDK.DefaultBatchSize
        public var retries = ZcashSDK.defaultRetries
        public var maxBackoffInterval = ZcashSDK.defaultMaxBackOffInterval
        public var rewindDistance = ZcashSDK.defaultRewindDistance
        public var walletBirthday: BlockHeight

        private(set) var network: ZcashNetwork
        private(set) var saplingActivation: BlockHeight

        public var blockPollInterval: TimeInterval {
            TimeInterval.random(in: ZcashSDK.defaultPollInterval / 2 ... ZcashSDK.defaultPollInterval * 1.5)
        }
        
        init (
            cacheDb: URL,
            dataDb: URL,
            downloadBatchSize: Int,
            retries: Int,
            maxBackoffInterval: TimeInterval,
            rewindDistance: Int,
            walletBirthday: BlockHeight,
            saplingActivation: BlockHeight,
            network: ZcashNetwork
        ) {
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.network = network
            self.downloadBatchSize = downloadBatchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.walletBirthday = walletBirthday
            self.saplingActivation = saplingActivation
        }
        
        public init(cacheDb: URL, dataDb: URL, walletBirthday: BlockHeight, network: ZcashNetwork) {
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.walletBirthday = walletBirthday
            self.saplingActivation = network.constants.saplingActivationHeight
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
        Processor is Enhancing transactions
        */
        case enhancing
        
        /**
        fetching utxos
        */
        case fetching

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

    var config: Configuration {
        willSet {
            self.stop()
        }
    }
    var maxAttemptsReached: Bool {
        self.retryAttempts >= self.config.retries
    }
    var shouldStart: Bool {
        switch self.state {
        case .stopped, .synced, .error:
            return !maxAttemptsReached
        default:
            return false
        }
    }

    private var service: LightWalletService
    private var downloader: CompactBlockDownloading
    private var storage: CompactBlockStorage
    private var transactionRepository: TransactionRepository
    private var accountRepository: AccountRepository
    private var rustBackend: ZcashRustBackendWelding.Type
    private var retryAttempts: Int = 0
    private var backoffTimer: Timer?
    private var lowerBoundHeight: BlockHeight?
    private var latestBlockHeight: BlockHeight
    private var lastChainValidationFailure: BlockHeight?
    private var consecutiveChainValidationErrors: Int = 0
    private var processingError: Error?
    private var foundBlocks = false
    private var maxAttempts: Int {
        config.retries
    }
    
    private var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }

    private var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "CompactBlockProcessorQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /**
    Initializes a CompactBlockProcessor instance
    - Parameters:
    - downloader: an instance that complies to CompactBlockDownloading protocol
    - backend: a class that complies to ZcashRustBackendWelding
    */
    convenience init(
        service: LightWalletService,
        storage: CompactBlockStorage,
        backend: ZcashRustBackendWelding.Type,
        config: Configuration
    ) {
        self.init(
            service: service,
            storage: storage,
            backend: backend,
            config: config,
            repository: TransactionRepositoryBuilder.build(
                dataDbURL: config.dataDb
            ),
            accountRepository: AccountRepositoryBuilder.build(dataDbURL: config.dataDb, readOnly: true)
        )
    }
    
    /**
    Initializes a CompactBlockProcessor instance from an Initialized object
    - Parameters:
        - initializer: an instance that complies to CompactBlockDownloading protocol
    */
    public convenience init(initializer: Initializer) {
        self.init(
            service: initializer.lightWalletService,
            storage: initializer.storage,
            backend: initializer.rustBackend,
            config: Configuration(
                cacheDb: initializer.cacheDbURL,
                dataDb: initializer.dataDbURL,
                walletBirthday: initializer.walletBirthday.height,
                network: initializer.network
            ),
            repository: initializer.transactionRepository,
            accountRepository: initializer.accountRepository
        )
    }
    
    internal init(
        service: LightWalletService,
        storage: CompactBlockStorage,
        backend: ZcashRustBackendWelding.Type,
        config: Configuration,
        repository: TransactionRepository,
        accountRepository: AccountRepository
    ) {
        self.service = service
        self.downloader = CompactBlockDownloader(service: service, storage: storage)
        self.rustBackend = backend
        self.storage = storage
        self.config = config
        self.transactionRepository = repository
        self.latestBlockHeight = config.walletBirthday
        self.accountRepository = accountRepository
    }
    
    deinit {
        self.operationQueue.cancelAllOperations()
    }

    static func validateServerInfo(
        _ info: LightWalletdInfo,
        saplingActivation: BlockHeight,
        localNetwork: ZcashNetwork,
        rustBackend: ZcashRustBackendWelding.Type
    ) throws {
        // check network types
        guard let remoteNetworkType = NetworkType.forChainName(info.chainName) else {
            throw CompactBlockProcessorError.generalError(
                message: "Chain name does not match. Expected either 'test' or 'main' but received '\(info.chainName)'." +
                    "this is probably an API or programming error"
            )
        }

        guard remoteNetworkType == localNetwork.networkType else {
            throw CompactBlockProcessorError.networkMismatch(expected: localNetwork.networkType, found: remoteNetworkType)
        }

        guard saplingActivation == info.saplingActivationHeight else {
            throw CompactBlockProcessorError.saplingActivationMismatch(expected: saplingActivation, found: BlockHeight(info.saplingActivationHeight))
        }

        // check branch id
        let localBranch = try rustBackend.consensusBranchIdFor(height: Int32(info.blockHeight), networkType: localNetwork.networkType)

        guard let remoteBranchID = ConsensusBranchID.fromString(info.consensusBranchID) else {
            throw CompactBlockProcessorError.generalError(message: "Consensus BranchIDs don't match this is probably an API or programming error")
        }

        guard remoteBranchID == localBranch else {
            throw CompactBlockProcessorError.wrongConsensusBranchId(expectedLocally: localBranch, found: remoteBranchID)
        }
    }

    static func nextBatchBlockRange(latestHeight: BlockHeight, latestDownloadedHeight: BlockHeight, walletBirthday: BlockHeight) -> CompactBlockRange {
        let lowerBound = latestDownloadedHeight <= walletBirthday ? walletBirthday : latestDownloadedHeight + 1

        let upperBound = latestHeight
        return lowerBound ... upperBound
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
            self.backoffTimer?.invalidate()
            self.backoffTimer = nil
        }
        guard !operationQueue.isSuspended else {
            LoggerProxy.debug("restarting suspended queue")
            operationQueue.isSuspended = false
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

        self.nextBatch()
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
            operationQueue.cancelAllOperations()
        } else {
            self.operationQueue.isSuspended = true
        }

        self.retryAttempts = 0
        self.state = .stopped
    }

    /**
    Rewinds to provided height.
    If nil is provided, it will rescan to nearest height (quick rescan)
    */
    public func rewindTo(_ height: BlockHeight?) throws -> BlockHeight {
        self.stop()

        let lastDownloaded = try downloader.lastDownloadedBlockHeight()
        let height = Int32(height ?? lastDownloaded)
        let nearestHeight = rustBackend.getNearestRewindHeight(dbData: config.dataDb, height: height, networkType: self.config.network.networkType)

        guard nearestHeight > 0 else {
            let error = rustBackend.lastError() ?? RustWeldingError.genericError(
                message: "unknown error getting nearest rewind height for height: \(height)"
            )
            fail(error)
            throw error
        }

        // FIXME: this should be done on the rust layer
        let rewindHeight = max(Int32(nearestHeight - 1), Int32(config.walletBirthday))
        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: rewindHeight, networkType: self.config.network.networkType) else {
            let error = rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)")
            fail(error)
            throw error
        }

        // clear cache
        try downloader.rewind(to: BlockHeight(rewindHeight))
        self.lastChainValidationFailure = nil
        self.lowerBoundHeight = try? downloader.lastDownloadedBlockHeight()
        return BlockHeight(rewindHeight)
    }
    /**
    changes the wallet birthday in configuration. Use this method when wallet birthday is not available and the processor can't be lazy initialized.
    - Note: this does not rewind your chain state
    - Parameter startHeight: the wallet birthday for this compact block processor
    - Throws CompactBlockProcessorError.invalidConfiguration if block height is invalid or if processor is already started
    */
    func setStartHeight(_ startHeight: BlockHeight) throws {
        guard self.state == .stopped, startHeight >= config.network.constants.saplingActivationHeight else {
            throw CompactBlockProcessorError.invalidConfiguration
        }

        var config = self.config
        config.walletBirthday = startHeight
        self.config = config
    }

    func validateServer(completionBlock: @escaping (() -> Void)) {
        self.service.getInfo(result: { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let info):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    do {
                        try Self.validateServerInfo(
                            info,
                            saplingActivation: self.config.saplingActivation,
                            localNetwork: self.config.network,
                            rustBackend: self.rustBackend
                        )
                        completionBlock()
                    } catch {
                        self.severeFailure(error)
                    }
                }
            case .failure(let error):
                self.severeFailure(error.mapToProcessorError())
            }
        })
    }

    /**
    processes new blocks on the given range based on the configuration set for this instance
    the way operations are queued is implemented based on the following good practice https://forums.developer.apple.com/thread/25761
     
    */
    // swiftlint:disable cyclomatic_complexity
    func processNewBlocks(range: CompactBlockRange) {
        self.foundBlocks = true
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil
        
        let cfg = self.config
        
        let downloadBlockOperation = CompactBlockBatchDownloadOperation(
            service: self.service,
            storage: self.storage,
            startHeight: range.lowerBound,
            targetHeight: range.upperBound,
            progressDelegate: self
        )
        
        downloadBlockOperation.startedHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.state = .downloading
            }
        }
        
        downloadBlockOperation.errorHandler = { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.processingError = error
                self.fail(error)
            }
        }
        
        let validateChainOperation = CompactBlockValidationOperation(
            rustWelding: self.rustBackend,
            cacheDb: cfg.cacheDb,
            dataDb: cfg.dataDb,
            networkType: self.config.network.networkType
        )
        
        let downloadValidateAdapterOperation = BlockOperation { [weak validateChainOperation, weak downloadBlockOperation] in
            validateChainOperation?.error = downloadBlockOperation?.error
        }
        
        validateChainOperation.completionHandler = { [weak self] _, cancelled in
            guard !cancelled else {
                DispatchQueue.main.async {
                    self?.state = .stopped
                    LoggerProxy.debug("Warning: validateChainOperation operation cancelled")
                }
                return
            }
            
            LoggerProxy.debug("validateChainFinished")
        }
        
        validateChainOperation.errorHandler = { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                guard let validationError = error as? CompactBlockValidationError else {
                    LoggerProxy.error("Warning: validateChain operation returning generic error: \(error)")
                    return
                }
                
                switch validationError {
                case .validationFailed(let height):
                    LoggerProxy.debug("chain validation at height: \(height)")
                    self.validationFailed(at: height)
                case .failedWithError(let e):
                    guard let validationFailure = e else {
                        LoggerProxy.error("validation failed without a specific error")
                        self.fail(CompactBlockProcessorError.generalError(message: "validation failed without a specific error"))
                        return
                    }
                    
                    self.fail(validationFailure)
                }
            }
        }
        
        validateChainOperation.startedHandler = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.state = .validating
            }
        }
        
        let scanBlocksOperation = CompactBlockBatchScanningOperation(
            rustWelding: rustBackend,
            cacheDb: config.cacheDb,
            dataDb: config.dataDb,
            transactionRepository: transactionRepository,
            range: range,
            networkType: self.config.network.networkType,
            progressDelegate: self
        )
        
        let validateScanningAdapterOperation = BlockOperation { [weak scanBlocksOperation, weak validateChainOperation] in
            scanBlocksOperation?.error = validateChainOperation?.error
        }

        scanBlocksOperation.startedHandler = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.state = .scanning
            }
        }
        
        scanBlocksOperation.completionHandler = { [weak self] _, cancelled in
            guard !cancelled else {
                DispatchQueue.main.async { [weak self] in
                    self?.state = .stopped
                    LoggerProxy.debug("Warning: scanBlocksOperation operation cancelled")
                }
                return
            }
        }
        
        scanBlocksOperation.errorHandler = { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.processingError = error
                self.fail(error)
            }
        }
        
        let enhanceOperation = CompactBlockEnhancementOperation(
            rustWelding: rustBackend,
            dataDb: config.dataDb,
            downloader: downloader,
            repository: transactionRepository,
            range: range.blockRange(),
            networkType: self.config.network.networkType
        )
        
        enhanceOperation.startedHandler = {
            LoggerProxy.debug("Started Enhancing range: \(range)")
            DispatchQueue.main.async { [weak self] in
                self?.state = .enhancing
            }
        }
        
        enhanceOperation.txFoundHandler = { [weak self] txs, range in
            self?.notifyTransactions(txs, in: range)
        }
        
        enhanceOperation.completionHandler  = { _, cancelled in
            guard !cancelled else {
                LoggerProxy.debug("Warning: enhance operation on range \(range) cancelled")
                return
            }
        }
        
        enhanceOperation.errorHandler = { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.processingError = error
                self.fail(error)
            }
        }
        
        let scanEnhanceAdapterOperation = BlockOperation { [weak enhanceOperation, weak scanBlocksOperation] in
            enhanceOperation?.error = scanBlocksOperation?.error
        }
        
        let fetchOperation = FetchUnspentTxOutputsOperation(
            accountRepository: accountRepository,
            downloader: self.downloader,
            rustbackend: rustBackend,
            dataDb: config.dataDb,
            startHeight: config.walletBirthday,
            networkType: self.config.network.networkType
        )
        
        fetchOperation.startedHandler = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.state = .fetching
            }
        }
        
        fetchOperation.completionHandler = {  [weak self] _, cancelled in
            guard !cancelled else {
                LoggerProxy.debug("Warning: fetch operation on range \(range) cancelled")
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.processBatchFinished(range: range)
            }
        }

        fetchOperation.errorHandler = { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.processingError = error
                self.fail(error)
            }
        }

        fetchOperation.fetchedUTXOsHandler = { result in
            NotificationCenter.default.post(
                name: .blockProcessorStoredUTXOs,
                object: self,
                userInfo: [CompactBlockProcessorNotificationKey.refreshedUTXOs: result]
            )
        }
        
        let enhanceFetchAdapterOperation = BlockOperation { [weak fetchOperation, weak enhanceOperation] in
            fetchOperation?.error = enhanceOperation?.error
        }
        
        downloadValidateAdapterOperation.addDependency(downloadBlockOperation)
        validateChainOperation.addDependency(downloadValidateAdapterOperation)
        validateScanningAdapterOperation.addDependency(validateChainOperation)
        scanBlocksOperation.addDependency(validateScanningAdapterOperation)
        scanEnhanceAdapterOperation.addDependency(scanBlocksOperation)
        enhanceOperation.addDependency(scanEnhanceAdapterOperation)
        enhanceFetchAdapterOperation.addDependency(enhanceOperation)
        fetchOperation.addDependency(enhanceFetchAdapterOperation)
        
        operationQueue.addOperations(
            [
                downloadBlockOperation,
                downloadValidateAdapterOperation,
                validateChainOperation,
                validateScanningAdapterOperation,
                scanBlocksOperation,
                scanEnhanceAdapterOperation,
                enhanceOperation,
                enhanceFetchAdapterOperation,
                fetchOperation
            ],
            waitUntilFinished: false
        )
    }
    
    func calculateProgress(start: BlockHeight, current: BlockHeight, latest: BlockHeight) -> Float {
        let totalBlocks = Float(abs(latest - start))
        let completed = Float(abs(current - start))
        let progress = completed / totalBlocks
        return progress
    }
    
    func notifyProgress(_ progress: CompactBlockProgress) {
        var userInfo: [AnyHashable: Any] = [:]
        userInfo[CompactBlockProcessorNotificationKey.progress] = progress

        LoggerProxy.debug("progress: \(progress)")
        
        NotificationCenter.default.post(
            name: Notification.Name.blockProcessorUpdated,
            object: self,
            userInfo: userInfo
        )
    }
    
    func notifyTransactions(_ txs: [ConfirmedTransactionEntity], in range: BlockRange) {
        NotificationCenter.default.post(
            name: .blockProcessorFoundTransactions,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.foundTransactions: txs,
                CompactBlockProcessorNotificationKey.foundTransactionsRange: ClosedRange(uncheckedBounds: (range.start.height, range.end.height))
            ]
        )
    }

    func determineLowerBound(
        errorHeight: Int,
        consecutiveErrors: Int,
        walletBirthday: BlockHeight
    ) -> BlockHeight {
        let offset = min(ZcashSDK.maxReorgSize, ZcashSDK.defaultRewindDistance * (consecutiveErrors + 1))
        return max(errorHeight - offset, walletBirthday - ZcashSDK.maxReorgSize)
    }

    func severeFailure(_ error: Error) {
        operationQueue.cancelAllOperations()
        LoggerProxy.error("show stoppper failure: \(error)")
        self.backoffTimer?.invalidate()
        self.retryAttempts = config.retries
        self.processingError = error
        self.state = .error(error)
        self.notifyError(error)
    }

    func fail(_ error: Error) {
        // todo specify: failure
        LoggerProxy.error("\(error)")
        operationQueue.cancelAllOperations()
        self.retryAttempts += 1
        self.processingError = error
        switch self.state {
        case .error:
            notifyError(error)
        default:
            break
        }
        self.state = .error(error)
        guard self.maxAttemptsReached else { return }
        // don't set a new timer if there are no more attempts.
        self.setTimer()
    }

    func retryProcessing(range: CompactBlockRange) {
        operationQueue.cancelAllOperations()
        // update retries
        self.retryAttempts += 1
        self.processingError = nil
        guard self.retryAttempts < config.retries else {
            self.notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.retryAttempts))
            self.stop()
            return
        }

        do {
            try downloader.rewind(to: max(range.lowerBound, self.config.walletBirthday))

            // process next batch
            // processNewBlocks(range: Self.nextBatchBlockRange(latestHeight: latestBlockHeight, latestDownloadedHeight: try downloader.lastDownloadedBlockHeight(), walletBirthday: config.walletBirthday))
            nextBatch()
        } catch {
            self.fail(error)
        }
    }

    func mapError(_ error: Error) -> CompactBlockProcessorError {
        if let processorError = error as? CompactBlockProcessorError {
            return processorError
        }
        if let lwdError = error as? LightWalletServiceError {
            return lwdError.mapToProcessorError()
        } else if let rpcError = error as? GRPC.GRPCStatus {
            switch rpcError {
            case .ok:
                LoggerProxy.warn("Error Raised when status is OK")
                return CompactBlockProcessorError.grpcError(
                    statusCode: rpcError.code.rawValue,
                    message: rpcError.message ?? "Error Raised when status is OK"
                )
            default:
                return CompactBlockProcessorError.grpcError(statusCode: rpcError.code.rawValue, message: rpcError.message ?? "No message")
            }
        }
        return .unspecifiedError(underlyingError: error)
    }

    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.cacheDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.cacheDb.absoluteString)
        }

        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDb.absoluteString)
        }
    }

    private func nextBatch() {
        self.state = .downloading
        NextStateHelper.nextState(
            service: self.service,
            downloader: self.downloader,
            config: self.config,
            rustBackend: self.rustBackend,
            queue: nil
        ) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let nextState):
                    switch nextState {
                    case .finishProcessing(let height):
                        self.latestBlockHeight = height
                        self.processingFinished(height: height)
                    case .processNewBlocks(let range):
                        self.latestBlockHeight = range.upperBound
                        self.lowerBoundHeight = range.lowerBound
                        self.processNewBlocks(range: range)
                    case let .wait(latestHeight, latestDownloadHeight):
                        // Lightwalletd might be syncing
                        self.lowerBoundHeight = latestDownloadHeight
                        self.latestBlockHeight = latestHeight
                        LoggerProxy.info(
                            "Lightwalletd might be syncing: latest downloaded block height is: \(latestDownloadHeight)" +
                            "while latest blockheight is reported at: \(latestHeight)"
                        )
                        self.processingFinished(height: latestDownloadHeight)
                    }
                case .failure(let error):
                    self.severeFailure(error)
                }
            }
        }
    }

    private func validationFailed(at height: BlockHeight) {
        // cancel all Tasks
        operationQueue.cancelAllOperations()

        // register latest failure
        self.lastChainValidationFailure = height
        self.consecutiveChainValidationErrors += 1
        
        // rewind
        let rewindHeight = determineLowerBound(
            errorHeight: height,
            consecutiveErrors: consecutiveChainValidationErrors,
            walletBirthday: self.config.walletBirthday
        )

        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: Int32(rewindHeight), networkType: self.config.network.networkType) else {
            fail(rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)"))
            return
        }
        
        do {
            try downloader.rewind(to: rewindHeight)
            
            // notify reorg
            NotificationCenter.default.post(
                name: Notification.Name.blockProcessorHandledReOrg,
                object: self,
                userInfo: [
                    CompactBlockProcessorNotificationKey.reorgHeight: height, CompactBlockProcessorNotificationKey.rewindHeight: rewindHeight
                ]
            )
            
            // process next batch
            self.nextBatch()
        } catch {
            self.fail(error)
        }
    }

    private func processBatchFinished(range: CompactBlockRange) {
        guard processingError == nil else {
            retryProcessing(range: range)
            return
        }
        
        retryAttempts = 0
        consecutiveChainValidationErrors = 0
        
        guard !range.isEmpty else {
            processingFinished(height: range.upperBound)
            return
        }
        
        nextBatch()
    }
    
    private func processingFinished(height: BlockHeight) {
        NotificationCenter.default.post(
            name: Notification.Name.blockProcessorFinished,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.latestScannedBlockHeight: height,
                CompactBlockProcessorNotificationKey.foundBlocks: self.foundBlocks
            ]
        )
        self.state = .synced
        setTimer()
    }
    
    private func setTimer() {
        let interval = self.config.blockPollInterval
        self.backoffTimer?.invalidate()
        let timer = Timer(
            timeInterval: interval,
            repeats: true,
            block: { [weak self] _ in
                guard let self = self else { return }
                do {
                    if self.shouldStart {
                        LoggerProxy.debug(
                            """
                            Timer triggered: Starting compact Block processor!.
                            Processor State: \(self.state)
                            latestHeight: \(self.latestBlockHeight)
                            attempts: \(self.retryAttempts)
                            lowerbound: \(String(describing: self.lowerBoundHeight))
                            """
                        )
                        try self.start()
                    } else if self.maxAttemptsReached {
                        self.fail(CompactBlockProcessorError.maxAttemptsReached(attempts: self.config.retries))
                    }
                } catch {
                    self.fail(error)
                }
            }
        )
        RunLoop.main.add(timer, forMode: .default)
        
        self.backoffTimer = timer
    }
    
    private func transitionState(from oldValue: State, to newValue: State) {
        guard oldValue != newValue else {
            return
        }

        NotificationCenter.default.post(
            name: .blockProcessorStatusChanged,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.previousStatus: oldValue,
                CompactBlockProcessorNotificationKey.newStatus: newValue
            ]
        )
        
        switch newValue {
        case .downloading:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedDownloading, object: self)
        case .synced:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorFinished, object: self)
        case .error(let err):
            notifyError(err)
        case .scanning:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedScanning, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStopped, object: self)
        case .validating:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedValidating, object: self)
        case .enhancing:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedEnhancing, object: self)
        case .fetching:
            NotificationCenter.default.post(name: Notification.Name.blockProcessorStartedFetching, object: self)
        }
    }

    private func notifyError(_ err: Error) {
        NotificationCenter.default.post(
            name: Notification.Name.blockProcessorFailed,
            object: self,
            userInfo: [CompactBlockProcessorNotificationKey.error: mapError(err)]
        )
    }
    // TODO: encapsulate service errors better
}

public extension CompactBlockProcessor.Configuration {
    /**
    Standard configuration for most compact block processors
    */
    static func standard(for network: ZcashNetwork, walletBirthday: BlockHeight) -> CompactBlockProcessor.Configuration {
        let pathProvider = DefaultResourceProvider(network: network)
        return CompactBlockProcessor.Configuration(
            cacheDb: pathProvider.cacheDbURL,
            dataDb: pathProvider.dataDbURL,
            walletBirthday: walletBirthday,
            network: network
        )
    }
}

extension LightWalletServiceError {
    func mapToProcessorError() -> CompactBlockProcessorError {
        switch self {
        case let .failed(statusCode, message):
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
        case
            (.downloading, .downloading),
            (.scanning, .scanning),
            (.validating, .validating),
            (.stopped, .stopped),
            (.error, .error),
            (.synced, .synced),
            (.enhancing, enhancing),
            (.fetching, .fetching):
            return true
        default:
            return false
        }
    }
}

// Transparent stuff

extension CompactBlockProcessor {
    public func utxoCacheBalance(tAddress: String) throws -> WalletBalance {
        try rustBackend.downloadedUtxoBalance(dbData: config.dataDb, address: tAddress, networkType: config.network.networkType)
    }
}

extension CompactBlockProcessor {
    public func getUnifiedAddres(accountIndex: Int) -> UnifiedAddress? {
        guard let account = try? accountRepository.findBy(account: accountIndex) else {
            return nil
        }
        return UnifiedAddressShim(account: account)
    }
    
    public func getShieldedAddress(accountIndex: Int) -> SaplingShieldedAddress? {
        try? accountRepository.findBy(account: accountIndex)?.address
    }
    
    public func getTransparentAddress(accountIndex: Int) -> TransparentAddress? {
        try? accountRepository.findBy(account: accountIndex)?.transparentAddress
    }
    
    public func getTransparentBalance(accountIndex: Int) throws -> WalletBalance {
        guard let tAddress = try? accountRepository.findBy(account: accountIndex)?.transparentAddress else {
            throw CompactBlockProcessorError.invalidAccount
        }
        return try utxoCacheBalance(tAddress: tAddress)
    }
}

private struct UnifiedAddressShim {
    let account: AccountEntity
}

extension UnifiedAddressShim: UnifiedAddress {
    var tAddress: TransparentAddress {
        account.transparentAddress
    }
    
    var zAddress: SaplingShieldedAddress {
        account.address
    }
}

extension CompactBlockProcessor {
    func refreshUTXOs(tAddress: String, startHeight: BlockHeight, result: @escaping (Result<RefreshedUTXOs, Error>) -> Void) {
        let dataDb = self.config.dataDb
        self.downloader.fetchUnspentTransactionOutputs(tAddress: tAddress, startHeight: startHeight) { [weak self] fetchResult in
            switch fetchResult {
            case .success(let utxos):
                DispatchQueue.main.async {
                    self?.operationQueue.addOperation { [self] in
                        guard let self = self else { return }
                        do {
                            guard try self.rustBackend.clearUtxos(
                                dbData: dataDb,
                                address: tAddress,
                                sinceHeight: startHeight - 1,
                                networkType: self.config.network.networkType
                            ) >= 0 else {
                                result(.failure(CompactBlockProcessorError.generalError(message: "attempted to clear utxos but -1 was returned")))
                                return
                            }
                        } catch {
                            result(.failure(self.mapError(error)))
                        }
                        result(.success(self.storeUTXOs(utxos, in: dataDb)))
                    }
                }
            case .failure(let error):
                result(.failure(self?.mapError(error) ?? error))
            }
        }
    }
    
    private func storeUTXOs(_ utxos: [UnspentTransactionOutputEntity], in dataDb: URL) -> RefreshedUTXOs {
        var refreshed: [UnspentTransactionOutputEntity] = []
        var skipped: [UnspentTransactionOutputEntity] = []
        for utxo in utxos {
            do {
                try self.rustBackend.putUnspentTransparentOutput(
                    dbData: dataDb,
                    address: utxo.address,
                    txid: utxo.txid.bytes,
                    index: utxo.index,
                    script: utxo.script.bytes,
                    value: Int64(utxo.valueZat),
                    height: utxo.height,
                    networkType: self.config.network.networkType
                ) ? refreshed.append(utxo) : skipped.append(utxo)
            } catch {
                LoggerProxy.info("failed to put utxo - error: \(error)")
                skipped.append(utxo)
            }
        }
        return (inserted: refreshed, skipped: skipped)
    }
}

extension CompactBlockProcessorError: LocalizedError {
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .dataDbInitFailed(let path):
            return "Data Db file couldn't be initialized at path: \(path)"
        case .connectionError(let underlyingError):
            return "There's a problem with the Network Connection. Underlying error: \(underlyingError.localizedDescription)"
        case .connectionTimeout:
            return "Network connection timeout"
        case .criticalError:
            return "Critical Error"
        case .generalError(let message):
            return "Error Processing Blocks - \(message)"
        case let .grpcError(statusCode, message):
            return "Error on gRPC - Status Code: \(statusCode) - Message: \(message)"
        case .invalidAccount:
            return "Invalid Account"
        case .invalidConfiguration:
            return "CompactBlockProcessor was started with an Invalid Configuration"
        case .maxAttemptsReached(let attempts):
            return "Compact Block failed \(attempts) times and reached the maximum amount of retries it was set up to do"
        case .missingDbPath(let path):
            return "CompactBlockProcessor was set up with path \(path) but thath location couldn't be reached"
        case let .networkMismatch(expected, found):
            // swiftlint:disable:next line_length
            return "A server was reached, but it's targeting the wrong network Type. App Expected \(expected) but found \(found). Make sure you are pointing to the right server"
        case let .saplingActivationMismatch(expected, found):
            // swiftlint:disable:next line_length
            return "A server was reached, it's showing a different sapling activation. App expected sapling activation height to be \(expected) but instead it found \(found). Are you sure you are pointing to the right server?"
        case .unspecifiedError(let underlyingError):
            return "Unspecified error caused by this underlying error: \(underlyingError)"
        case let .wrongConsensusBranchId(expectedLocally, found):
            // swiftlint:disable:next line_length
            return "The remote server you are connecting to is publishing a different branch ID \(found) than the one your App is expecting to be (\(expectedLocally)). This could be caused by your App being out of date or the server you are connecting you being either on a different network or out of date after a network upgrade."
        }
    }

    /// A localized message describing the reason for the failure.
    public var failureReason: String? {
        self.localizedDescription
    }

    /// A localized message describing how one might recover from the failure.
    public var recoverySuggestion: String? {
        self.localizedDescription
    }

    /// A localized message providing "help" text if the user requests help.
    public var helpAnchor: String? {
        self.localizedDescription
    }
}

extension CompactBlockProcessor: CompactBlockProgressDelegate {
    func progressUpdated(_ progress: CompactBlockProgress) {
        notifyProgress(progress)
    }
}

extension CompactBlockProcessor: EnhancementStreamDelegate {
    func transactionEnhancementProgressUpdated(_ progress: EnhancementProgress) {
        NotificationCenter.default.post(
            name: .blockProcessorEnhancementProgress,
            object: self,
            userInfo: [CompactBlockProcessorNotificationKey.enhancementProgress: progress]
        )
    }
}

extension CompactBlockProcessor {
    enum NextStateHelper {
        // swiftlint:disable:next function_parameter_count
        static func nextState(
            service: LightWalletService,
            downloader: CompactBlockDownloading,
            config: Configuration,
            rustBackend: ZcashRustBackendWelding.Type,
            queue: DispatchQueue?,
            result: @escaping (Result<FigureNextBatchOperation.NextState, Error>) -> Void
        ) {
            let dispatchQueue = queue ?? DispatchQueue.global(qos: .userInitiated)
            
            dispatchQueue.async {
                do {
                    let nextResult = try self.nextState(
                        service: service,
                        downloader: downloader,
                        config: config,
                        rustBackend: rustBackend
                    )
                    result(.success(nextResult))
                } catch {
                    result(.failure(error))
                }
            }
        }
        
        static func nextState(
            service: LightWalletService,
            downloader: CompactBlockDownloading,
            config: Configuration,
            rustBackend: ZcashRustBackendWelding.Type
        ) throws -> FigureNextBatchOperation.NextState {
            let info = try service.getInfo()
            
            try CompactBlockProcessor.validateServerInfo(
                info,
                saplingActivation: config.saplingActivation,
                localNetwork: config.network,
                rustBackend: rustBackend
            )
            
            // get latest block height
            let latestDownloadedBlockHeight: BlockHeight = max(config.walletBirthday, try downloader.lastDownloadedBlockHeight())
            
            let latestBlockheight = try service.latestBlockHeight()
            
            if latestDownloadedBlockHeight < latestBlockheight {
                return .processNewBlocks(
                    range: CompactBlockProcessor.nextBatchBlockRange(
                        latestHeight: latestBlockheight,
                        latestDownloadedHeight: latestDownloadedBlockHeight,
                        walletBirthday: config.walletBirthday
                    )
                )
            } else if latestBlockheight == latestDownloadedBlockHeight {
                return .finishProcessing(height: latestBlockheight)
            }
                
            return .wait(latestHeight: latestBlockheight, latestDownloadHeight: latestBlockheight)
        }
    }
}
