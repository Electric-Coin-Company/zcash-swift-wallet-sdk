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
    case unknown
    case rewindAttemptWhileProcessing
}

/**
CompactBlockProcessor notification userInfo object keys.
check Notification.Name extensions for more details.
*/
public enum CompactBlockProcessorNotificationKey {
    public static let progress = "CompactBlockProcessorNotificationKey.progress"
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
    func transactionEnhancementProgressUpdated(_ progress: EnhancementProgress) async
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
    
    static let blockProcessorHandlingSaplingFiles = Notification.Name(rawValue: "blockProcessorHandlingSaplingFiles")
    
    /**
    Notification sent when the grpc service connection detects a change. Query the user info object  for status change details `currentConnectivityStatus` for current and previous with `previousConnectivityStatus`
    */
    static let blockProcessorConnectivityStateChanged = Notification.Name("CompactBlockProcessorConnectivityStateChanged")
}


/// The compact block processor is in charge of orchestrating the download and caching of compact blocks from a LightWalletEndpoint
/// when started the processor downloads does a download - validate - scan cycle until it reaches latest height on the blockchain.
public actor CompactBlockProcessor {

    /// Compact Block Processor configuration
    ///
    /// Property: cacheDbPath absolute file path of the DB where raw, unprocessed compact blocks are stored.
    /// Property: dataDbPath absolute file path of the DB where all information derived from the cache DB is stored.
    /// Property: spendParamsURL absolute file path of the sapling-spend.params file
    /// Property: outputParamsURL absolute file path of the sapling-output.params file
    public struct Configuration {
        public var cacheDb: URL
        public var dataDb: URL
        public var spendParamsURL: URL
        public var outputParamsURL: URL
        public var downloadBatchSize = ZcashSDK.DefaultDownloadBatch
        public var scanningBatchSize = ZcashSDK.DefaultScanningBatch
        public var retries = ZcashSDK.defaultRetries
        public var maxBackoffInterval = ZcashSDK.defaultMaxBackOffInterval
        public var rewindDistance = ZcashSDK.defaultRewindDistance
        public var walletBirthday: BlockHeight
        public private(set) var downloadBufferSize: Int = 10
        private(set) var network: ZcashNetwork
        private(set) var saplingActivation: BlockHeight

        public var blockPollInterval: TimeInterval {
            TimeInterval.random(in: ZcashSDK.defaultPollInterval / 2 ... ZcashSDK.defaultPollInterval * 1.5)
        }
        
        init (
            cacheDb: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
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
            self.spendParamsURL = spendParamsURL
            self.outputParamsURL = outputParamsURL
            self.network = network
            self.downloadBatchSize = downloadBatchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.walletBirthday = walletBirthday
            self.saplingActivation = saplingActivation
        }
        
        public init(
            cacheDb: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            walletBirthday: BlockHeight,
            network: ZcashNetwork
        ) {
            self.cacheDb = cacheDb
            self.dataDb = dataDb
            self.spendParamsURL = spendParamsURL
            self.outputParamsURL = outputParamsURL
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

        /// Download sapling param files if needed.
        case handlingSaplingFiles

        /**
        Processor is up to date with the blockchain and you can now make transactions.
        */
        case synced
    }
    
    public internal(set) var state: State = .stopped {
        didSet {
            transitionState(from: oldValue, to: self.state)
        }
    }
    
    private var needsToStartScanningWhenStopped = false
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

    var service: LightWalletService
    private(set) var downloader: CompactBlockDownloading
    var storage: CompactBlockStorage
    var transactionRepository: TransactionRepository
    var accountRepository: AccountRepository
    var rustBackend: ZcashRustBackendWelding.Type
    private var retryAttempts: Int = 0
    private var backoffTimer: Timer?
    private var lastChainValidationFailure: BlockHeight?
    private var consecutiveChainValidationErrors: Int = 0
    var processingError: Error?
    private var foundBlocks = false
    private var maxAttempts: Int {
        config.retries
    }
    
    private var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }

    private var cancelableTask: Task<Void, Error>?

    let internalSyncProgress = InternalSyncProgress(storage: UserDefaults.standard)

    /// Initializes a CompactBlockProcessor instance
    /// - Parameters:
    ///  - service: concrete implementation of `LightWalletService` protocol
    ///  - storage: concrete implementation of `CompactBlockStorage` protocol
    ///  - backend: a class that complies to `ZcashRustBackendWelding`
    ///  - config: `Configuration` struct for this processor
    init(
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

    /// Initializes a CompactBlockProcessor instance from an Initialized object
    /// - Parameters:
    ///     - initializer: an instance that complies to CompactBlockDownloading protocol
    public init(initializer: Initializer) {
        self.init(
            service: initializer.lightWalletService,
            storage: initializer.storage,
            backend: initializer.rustBackend,
            config: Configuration(
                cacheDb: initializer.cacheDbURL,
                dataDb: initializer.dataDbURL,
                spendParamsURL: initializer.spendParamsURL,
                outputParamsURL: initializer.outputParamsURL,
                walletBirthday: Checkpoint.birthday(
                    with: initializer.walletBirthday,
                    network: initializer.network
                ).height,
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
        self.accountRepository = accountRepository
    }
    
    deinit {
        cancelableTask?.cancel()
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

    /// Starts the CompactBlockProcessor instance and starts downloading and processing blocks
    ///
    /// triggers the blockProcessorStartedDownloading notification
    ///
    /// - Important: subscribe to the notifications before calling this method
    public func start(retry: Bool = false) async {
        if retry {
            self.retryAttempts = 0
            self.processingError = nil
            self.backoffTimer?.invalidate()
            self.backoffTimer = nil
        }

        guard shouldStart else {
            switch self.state {
            case .error(let e):
                // max attempts have been reached
                LoggerProxy.info("max retry attempts reached with error: \(e)")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
                state = .stopped
            case .stopped:
                // max attempts have been reached
                LoggerProxy.info("max retry attempts reached")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
            case .synced:
                // max attempts have been reached
                LoggerProxy.warn("max retry attempts reached on synced state, this indicates malfunction")
                notifyError(CompactBlockProcessorError.maxAttemptsReached(attempts: self.maxAttempts))
            case .downloading, .validating, .scanning, .enhancing, .fetching, .handlingSaplingFiles:
                LoggerProxy.debug("Warning: compact block processor was started while busy!!!!")
                self.`needsToStartScanningWhenStopped` = true
            }
            return
        }

        await self.nextBatch()
    }

    /**
    Stops the CompactBlockProcessor

    Note: retry count is reset
    */
    public func stop() {
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil

        cancelableTask?.cancel()

        self.retryAttempts = 0
    }

    /**
    Rewinds to provided height.
    If nil is provided, it will rescan to nearest height (quick rescan)

    If this is called while sync is in progress then `CompactBlockProcessorError.rewindAttemptWhileProcessing` is thrown.
    */
    public func rewindTo(_ height: BlockHeight?) async throws -> BlockHeight {
        guard shouldStart else { throw CompactBlockProcessorError.rewindAttemptWhileProcessing }

        let lastDownloaded = await internalSyncProgress.latestDownloadedBlockHeight
        let height = Int32(height ?? lastDownloaded)
        let nearestHeight = rustBackend.getNearestRewindHeight(
            dbData: config.dataDb,
            height: height,
            networkType: self.config.network.networkType
        )

        guard nearestHeight > 0 else {
            let error = rustBackend.lastError() ?? RustWeldingError.genericError(
                message: "unknown error getting nearest rewind height for height: \(height)"
            )
            await fail(error)
            throw error
        }

        // FIXME: this should be done on the rust layer
        let rewindHeight = max(Int32(nearestHeight - 1), Int32(config.walletBirthday))
        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: rewindHeight, networkType: self.config.network.networkType) else {
            let error = rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)")
            await fail(error)
            throw error
        }

        // clear cache
        let rewindBlockHeight = BlockHeight(rewindHeight)
        try downloader.rewind(to: rewindBlockHeight)
        await internalSyncProgress.rewind(to: rewindBlockHeight)

        self.lastChainValidationFailure = nil
        return rewindBlockHeight
    }

    func validateServer() async {
        do {
            let info = try await self.service.getInfo()
            try Self.validateServerInfo(
                info,
                saplingActivation: self.config.saplingActivation,
                localNetwork: self.config.network,
                rustBackend: self.rustBackend
            )
        } catch let error as LightWalletServiceError {
            self.severeFailure(error.mapToProcessorError())
        } catch {
            self.severeFailure(error)
        }
    }
    
    /// Processes new blocks on the given range based on the configuration set for this instance
    func processNewBlocks(ranges: SyncRanges) async {
        self.foundBlocks = true
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil
        
        cancelableTask = Task(priority: .userInitiated) {
            do {
                LoggerProxy.debug("""
                Syncing with ranges:
                downloadRange:  \(ranges.downloadRange?.lowerBound ?? -1)...\(ranges.downloadRange?.upperBound ?? -1)
                scanRange:      \(ranges.scanRange?.lowerBound ?? -1)...\(ranges.scanRange?.upperBound ?? -1)
                enhanceRange:   \(ranges.enhanceRange?.lowerBound ?? -1)...\(ranges.enhanceRange?.upperBound ?? -1)
                fetchUTXORange: \(ranges.fetchUTXORange?.lowerBound ?? -1)...\(ranges.fetchUTXORange?.upperBound ?? -1)
                """)

                var anyActionExecuted = false

                try storage.createTable()

                if let range = ranges.downloadRange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Downloading with range: \(range.lowerBound)...\(range.upperBound)")

                    try await compactBlockStreamDownload(
                        blockBufferSize: config.downloadBufferSize,
                        startHeight: range.lowerBound,
                        targetHeight: range.upperBound
                    )

                    try await compactBlockValidation()
                }

                if let range = ranges.scanRange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Scanning with range: \(range.lowerBound)...\(range.upperBound)")
                    try await compactBlockBatchScanning(range: range)
                }

                if let range = ranges.enhanceRange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Enhancing with range: \(range.lowerBound)...\(range.upperBound)")
                    try await compactBlockEnhancement(range: range)
                }

                if let range = ranges.fetchUTXORange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Fetching UTXO with range: \(range.lowerBound)...\(range.upperBound)")
                    try await fetchUnspentTxOutputs(range: range)
                }

                try await handleSaplingParametersIfNeeded()
                try await removeCacheDB()

                if !Task.isCancelled {
                    await processBatchFinished(height: anyActionExecuted ? ranges.latestBlockHeight : nil)
                }
            } catch {
                LoggerProxy.error("Sync failed with error: \(error)")

                if !(Task.isCancelled) {
                    await fail(error)
                } else {
                    state = .stopped
                    if needsToStartScanningWhenStopped {
                        await nextBatch()
                    }
                }
            }
        }
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

        NotificationSender.default.post(
            name: Notification.Name.blockProcessorUpdated,
            object: self,
            userInfo: userInfo
        )
    }
    
    func notifyTransactions(_ txs: [ConfirmedTransactionEntity], in range: BlockRange) {
        NotificationSender.default.post(
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
        cancelableTask?.cancel()
        LoggerProxy.error("show stopper failure: \(error)")
        self.backoffTimer?.invalidate()
        self.retryAttempts = config.retries
        self.processingError = error
        state = .error(error)
        self.notifyError(error)
    }

    func fail(_ error: Error) async {
        // todo specify: failure
        LoggerProxy.error("\(error)")
        cancelableTask?.cancel()
        self.retryAttempts += 1
        self.processingError = error
        switch self.state {
        case .error:
            notifyError(error)
        default:
            break
        }
        state = .error(error)
        guard self.maxAttemptsReached else { return }
        // don't set a new timer if there are no more attempts.
        await self.setTimer()
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

    private func nextBatch() async {
        state = .downloading
        do {
            let nextState = try await NextStateHelper.nextStateAsync(
                service: self.service,
                downloader: self.downloader,
                transactionRepository: transactionRepository,
                config: self.config,
                rustBackend: self.rustBackend,
                internalSyncProgress: internalSyncProgress
            )
            switch nextState {
            case .finishProcessing(let height):
                await self.processingFinished(height: height)
            case .processNewBlocks(let ranges):
                await self.processNewBlocks(ranges: ranges)
            case let .wait(latestHeight, latestDownloadHeight):
                // Lightwalletd might be syncing
                LoggerProxy.info(
                    "Lightwalletd might be syncing: latest downloaded block height is: \(latestDownloadHeight) " +
                    "while latest blockheight is reported at: \(latestHeight)"
                )
                await self.processingFinished(height: latestDownloadHeight)
            }
        } catch {
            self.severeFailure(error)
        }
    }

    internal func validationFailed(at height: BlockHeight) async {
        // cancel all Tasks
        cancelableTask?.cancel()

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
            await fail(rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)"))
            return
        }
        
        do {
            try downloader.rewind(to: rewindHeight)
            await internalSyncProgress.rewind(to: rewindHeight)
            
            // notify reorg
            NotificationSender.default.post(
                name: Notification.Name.blockProcessorHandledReOrg,
                object: self,
                userInfo: [
                    CompactBlockProcessorNotificationKey.reorgHeight: height, CompactBlockProcessorNotificationKey.rewindHeight: rewindHeight
                ]
            )
            
            // process next batch
            await self.nextBatch()
        } catch {
            await self.fail(error)
        }
    }

    internal func processBatchFinished(height: BlockHeight?) async {
        retryAttempts = 0
        consecutiveChainValidationErrors = 0

        if let height {
            await processingFinished(height: height)
        } else {
            await nextBatch()
        }
    }
    
    private func processingFinished(height: BlockHeight) async {
        NotificationSender.default.post(
            name: Notification.Name.blockProcessorFinished,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.latestScannedBlockHeight: height,
                CompactBlockProcessorNotificationKey.foundBlocks: self.foundBlocks
            ]
        )
        state = .synced
        await setTimer()
        NotificationSender.default.post(
            name: Notification.Name.blockProcessorIdle,
            object: self,
            userInfo: nil
        )
    }

    private func removeCacheDB() async throws {
        storage.closeDBConnection()
        try FileManager.default.removeItem(at: config.cacheDb)
        try storage.createTable()
        LoggerProxy.info("Cache removed")
    }
    
    private func setTimer() async {
        let interval = self.config.blockPollInterval
        self.backoffTimer?.invalidate()
        let timer = Timer(
            timeInterval: interval,
            repeats: true,
            block: { [weak self] _ in
                Task { [self] in
                    guard let self = self else { return }
                    if await self.shouldStart {
                        LoggerProxy.debug(
                                """
                                Timer triggered: Starting compact Block processor!.
                                Processor State: \(await self.state)
                                latestHeight: \(try await self.transactionRepository.lastScannedHeight())
                                attempts: \(await self.retryAttempts)
                                """
                        )
                        await self.start()
                    } else if await self.maxAttemptsReached {
                        await self.fail(CompactBlockProcessorError.maxAttemptsReached(attempts: self.config.retries))
                    }
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

        NotificationSender.default.post(
            name: .blockProcessorStatusChanged,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.previousStatus: oldValue,
                CompactBlockProcessorNotificationKey.newStatus: newValue
            ]
        )
        
        switch newValue {
        case .downloading:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStartedDownloading, object: self)
        case .synced:
            // transition to this state is handled by `processingFinished(height: BlockHeight)`
            break
        case .error(let err):
            notifyError(err)
        case .scanning:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStartedScanning, object: self)
        case .stopped:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStopped, object: self)
        case .validating:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStartedValidating, object: self)
        case .enhancing:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStartedEnhancing, object: self)
        case .fetching:
            NotificationSender.default.post(name: Notification.Name.blockProcessorStartedFetching, object: self)
        case .handlingSaplingFiles:
            NotificationSender.default.post(name: Notification.Name.blockProcessorHandlingSaplingFiles, object: self)
        }
    }

    private func notifyError(_ err: Error) {
        NotificationSender.default.post(
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
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
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

extension CompactBlockProcessor {
    public func getUnifiedAddress(accountIndex: Int) -> UnifiedAddress? {
        try? rustBackend.getCurrentAddress(
            dbData: config.dataDb,
            account: Int32(accountIndex),
            networkType: config.network.networkType
        )
    }
    
    public func getSaplingAddress(accountIndex: Int) -> SaplingAddress? {
        getUnifiedAddress(accountIndex: accountIndex)?.saplingReceiver()
    }
    
    public func getTransparentAddress(accountIndex: Int) -> TransparentAddress? {
        getUnifiedAddress(accountIndex: accountIndex)?.transparentReceiver()
    }
    
    public func getTransparentBalance(accountIndex: Int) throws -> WalletBalance {
        guard accountIndex >= 0 else {
            throw CompactBlockProcessorError.invalidAccount
        }

        return WalletBalance(
            verified: Zatoshi(
                try rustBackend.getVerifiedTransparentBalance(
                    dbData: config.dataDb,
                    account: Int32(accountIndex),
                    networkType: config.network.networkType)
                ),
            total: Zatoshi(
                try rustBackend.getTransparentBalance(
                    dbData: config.dataDb,
                    account: Int32(accountIndex),
                    networkType: config.network.networkType
                )
            )
        )
    }
}

extension CompactBlockProcessor {
    func refreshUTXOs(tAddress: TransparentAddress, startHeight: BlockHeight) async throws -> RefreshedUTXOs {
        let dataDb = self.config.dataDb
        
        let stream: AsyncThrowingStream<UnspentTransactionOutputEntity, Error> = downloader.fetchUnspentTransactionOutputs(tAddress: tAddress.stringEncoded, startHeight: startHeight)
        var utxos: [UnspentTransactionOutputEntity] = []
        
        do {
            for try await utxo in stream {
                utxos.append(utxo)
            }
            return storeUTXOs(utxos, in: dataDb)
        } catch {
            throw mapError(error)
        }
    }
    
    private func storeUTXOs(_ utxos: [UnspentTransactionOutputEntity], in dataDb: URL) -> RefreshedUTXOs {
        var refreshed: [UnspentTransactionOutputEntity] = []
        var skipped: [UnspentTransactionOutputEntity] = []
        for utxo in utxos {
            do {
                try self.rustBackend.putUnspentTransparentOutput(
                    dbData: dataDb,
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
            return "CompactBlockProcessor was set up with path \(path) but that location couldn't be reached"
        case let .networkMismatch(expected, found):
            // swiftlint:disable:next line_length
            return "A server was reached, but it's targeting the wrong network Type. App Expected \(expected) but found \(found). Make sure you are pointing to the right server"
        case .rewindAttemptWhileProcessing:
            return "Can't execute rewind while sync process is in progress."
        case let .saplingActivationMismatch(expected, found):
            // swiftlint:disable:next line_length
            return "A server was reached, it's showing a different sapling activation. App expected sapling activation height to be \(expected) but instead it found \(found). Are you sure you are pointing to the right server?"
        case .unspecifiedError(let underlyingError):
            return "Unspecified error caused by this underlying error: \(underlyingError)"
        case let .wrongConsensusBranchId(expectedLocally, found):
            // swiftlint:disable:next line_length
            return "The remote server you are connecting to is publishing a different branch ID \(found) than the one your App is expecting to be (\(expectedLocally)). This could be caused by your App being out of date or the server you are connecting you being either on a different network or out of date after a network upgrade."
        case .unknown: return "Unknown error occurred."
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

extension CompactBlockProcessor: EnhancementStreamDelegate {
    func transactionEnhancementProgressUpdated(_ progress: EnhancementProgress) {
        NotificationSender.default.post(
            name: .blockProcessorEnhancementProgress,
            object: self,
            userInfo: [CompactBlockProcessorNotificationKey.enhancementProgress: progress]
        )
    }
}

extension CompactBlockProcessor {
    enum NextStateHelper {
        static func nextStateAsync(
            service: LightWalletService,
            downloader: CompactBlockDownloading,
            transactionRepository: TransactionRepository,
            config: Configuration,
            rustBackend: ZcashRustBackendWelding.Type,
            internalSyncProgress: InternalSyncProgress
        ) async throws -> CompactBlockProcessor.NextState {
            // It should be ok to not create new Task here because this method is already async. But for some reason something not good happens
            // when Task is not created here. For example tests start failing. Reason is unknown at this time.
            let task = Task(priority: .userInitiated) {
                let info = try await service.getInfo()

                try CompactBlockProcessor.validateServerInfo(
                    info,
                    saplingActivation: config.saplingActivation,
                    localNetwork: config.network,
                    rustBackend: rustBackend
                )

                await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: try downloader.lastDownloadedBlockHeight())

                let latestBlockHeight = try service.latestBlockHeight()
                let latestScannedHeight = try transactionRepository.lastScannedHeight()

                return try await internalSyncProgress.computeNextState(
                    latestBlockHeight: latestBlockHeight,
                    latestScannedHeight: latestScannedHeight,
                    walletBirthday: config.walletBirthday
                )
            }

            return try await task.value
        }
    }
}
