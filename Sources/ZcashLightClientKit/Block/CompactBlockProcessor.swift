//
//  CompactBlockProcessor.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
// swiftlint:disable file_length type_body_length

import Foundation
import Combine

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
}

public enum CompactBlockProgress {
    case syncing(_ progress: BlockProgress)
    case enhance(_ progress: EnhancementProgress)
    case fetch
    
    public var progress: Float {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.progress
        case .enhance(let enhancementProgress):
            return enhancementProgress.progress
        default:
            return 0
        }
    }
    
    public var progressHeight: BlockHeight? {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.progressHeight
        case .enhance(let enhancementProgress):
            return enhancementProgress.lastFoundTransaction?.minedHeight
        default:
            return 0
        }
    }
    
    public var blockDate: Date? {
        if case .enhance(let enhancementProgress) = self, let time = enhancementProgress.lastFoundTransaction?.blockTime {
            return Date(timeIntervalSince1970: time)
        }
        
        return nil
    }
    
    public var targetHeight: BlockHeight? {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.targetHeight
        default:
            return nil
        }
    }
}

public struct EnhancementProgress: Equatable {
    public var totalTransactions: Int
    public var enhancedTransactions: Int
    public var lastFoundTransaction: ZcashTransaction.Overview?
    public var range: CompactBlockRange

    public init(totalTransactions: Int, enhancedTransactions: Int, lastFoundTransaction: ZcashTransaction.Overview?, range: CompactBlockRange) {
        self.totalTransactions = totalTransactions
        self.enhancedTransactions = enhancedTransactions
        self.lastFoundTransaction = lastFoundTransaction
        self.range = range
    }
    
    public var progress: Float {
        totalTransactions > 0 ? Float(enhancedTransactions) / Float(totalTransactions) : 0
    }

    public static var zero: EnhancementProgress {
        EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0)
    }

    public static func == (lhs: EnhancementProgress, rhs: EnhancementProgress) -> Bool {
        return
            lhs.totalTransactions == rhs.totalTransactions &&
            lhs.enhancedTransactions == rhs.enhancedTransactions &&
            lhs.lastFoundTransaction?.id == rhs.lastFoundTransaction?.id &&
            lhs.range == rhs.range
    }
}

/// The compact block processor is in charge of orchestrating the download and caching of compact blocks from a LightWalletEndpoint
/// when started the processor downloads does a download - validate - scan cycle until it reaches latest height on the blockchain.
actor CompactBlockProcessor {
    enum Event {
        /// Event sent when the CompactBlockProcessor presented an error.
        case failed (CompactBlockProcessorError)

        /// Event sent when the CompactBlockProcessor has finished syncing the blockchain to latest height
        case finished (_ lastScannedHeight: BlockHeight, _ foundBlocks: Bool)

        /// Event sent when the CompactBlockProcessor enhanced a bunch of transactions in some range.
        case foundTransactions ([ZcashTransaction.Overview], CompactBlockRange)

        /// Event sent when the CompactBlockProcessor handled a ReOrg.
        /// `reorgHeight` is the height on which the reorg was detected.
        /// `rewindHeight` is the height that the processor backed to in order to solve the Reorg.
        case handledReorg (_ reorgHeight: BlockHeight, _ rewindHeight: BlockHeight)

        /// Event sent when progress of the sync process changes.
        case progressUpdated (CompactBlockProgress)

        /// Event sent when the CompactBlockProcessor fetched utxos from lightwalletd attempted to store them.
        case storedUTXOs ((inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]))

        /// Event sent when the CompactBlockProcessor starts enhancing of the transactions.
        case startedEnhancing

        /// Event sent when the CompactBlockProcessor starts fetching of the UTXOs.
        case startedFetching

        /// Event sent when the CompactBlockProcessor starts syncing.
        case startedSyncing

        /// Event sent when the CompactBlockProcessor stops syncing.
        case stopped
    }

    /// Compact Block Processor configuration
    ///
    /// - parameter fsBlockCacheRoot: absolute root path where the filesystem block cache will be stored.
    /// - parameter dataDb: absolute file path of the DB where all information derived from the cache DB is stored.
    /// - parameter spendParamsURL: absolute file path of the sapling-spend.params file
    /// - parameter outputParamsURL: absolute file path of the sapling-output.params file
    struct Configuration {
        let saplingParamsSourceURL: SaplingParamsSourceURL
        public var fsBlockCacheRoot: URL
        public var dataDb: URL
        public var spendParamsURL: URL
        public var outputParamsURL: URL
        public var downloadBatchSize = ZcashSDK.DefaultDownloadBatch
        public var scanningBatchSize = ZcashSDK.DefaultScanningBatch
        public var retries = ZcashSDK.defaultRetries
        public var maxBackoffInterval = ZcashSDK.defaultMaxBackOffInterval
        public var maxReorgSize = ZcashSDK.maxReorgSize
        public var rewindDistance = ZcashSDK.defaultRewindDistance
        let walletBirthdayProvider: () -> BlockHeight
        public var walletBirthday: BlockHeight { walletBirthdayProvider() }
        public private(set) var downloadBufferSize: Int = 10
        private(set) var network: ZcashNetwork
        private(set) var saplingActivation: BlockHeight
        private(set) var cacheDbURL: URL?
        var blockPollInterval: TimeInterval {
            TimeInterval.random(in: ZcashSDK.defaultPollInterval / 2 ... ZcashSDK.defaultPollInterval * 1.5)
        }
        
        init (
            cacheDbURL: URL? = nil,
            fsBlockCacheRoot: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            saplingParamsSourceURL: SaplingParamsSourceURL,
            downloadBatchSize: Int,
            retries: Int,
            maxBackoffInterval: TimeInterval,
            rewindDistance: Int,
            walletBirthdayProvider: @escaping () -> BlockHeight,
            saplingActivation: BlockHeight,
            network: ZcashNetwork
        ) {
            self.fsBlockCacheRoot = fsBlockCacheRoot
            self.dataDb = dataDb
            self.spendParamsURL = spendParamsURL
            self.outputParamsURL = outputParamsURL
            self.saplingParamsSourceURL = saplingParamsSourceURL
            self.network = network
            self.downloadBatchSize = downloadBatchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.walletBirthdayProvider = walletBirthdayProvider
            self.saplingActivation = saplingActivation
            self.cacheDbURL = cacheDbURL
            assert(downloadBatchSize >= scanningBatchSize)
        }
        
        init(
            fsBlockCacheRoot: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            saplingParamsSourceURL: SaplingParamsSourceURL,
            walletBirthdayProvider: @escaping () -> BlockHeight,
            network: ZcashNetwork
        ) {
            self.fsBlockCacheRoot = fsBlockCacheRoot
            self.dataDb = dataDb
            self.spendParamsURL = spendParamsURL
            self.outputParamsURL = outputParamsURL
            self.saplingParamsSourceURL = saplingParamsSourceURL
            self.walletBirthdayProvider = walletBirthdayProvider
            self.saplingActivation = network.constants.saplingActivationHeight
            self.network = network
            self.cacheDbURL = nil

            assert(downloadBatchSize >= scanningBatchSize)
        }
    }

    /**
    Represents the possible states of a CompactBlockProcessor
    */
    enum State {
        /**
        connected and downloading blocks
        */
        case syncing
        
        /**
        was doing something but was paused
        */
        case stopped

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
        case error(_ error: Error)

        /// Download sapling param files if needed.
        case handlingSaplingFiles

        /**
        Processor is up to date with the blockchain and you can now make transactions.
        */
        case synced
    }

    private var afterSyncHooksManager = AfterSyncHooksManager()
    
    var state: State = .stopped {
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

    var eventStream: AnyPublisher<Event, Never> { eventPublisher.eraseToAnyPublisher() }
    private let eventPublisher = PassthroughSubject<Event, Never>()

    let blockDownloaderService: BlockDownloaderService
    let blockDownloader: BlockDownloader
    let blockValidator: BlockValidator
    let blockScanner: BlockScanner
    let blockEnhancer: BlockEnhancer
    let utxoFetcher: UTXOFetcher
    let saplingParametersHandler: SaplingParametersHandler

    var service: LightWalletService
    var storage: CompactBlockRepository
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
    
    var batchSize: BlockHeight {
        BlockHeight(self.config.downloadBatchSize)
    }

    private var cancelableTask: Task<Void, Error>?

    let internalSyncProgress = InternalSyncProgress(storage: UserDefaults.standard)

    /// Initializes a CompactBlockProcessor instance
    /// - Parameters:
    ///  - service: concrete implementation of `LightWalletService` protocol
    ///  - storage: concrete implementation of `CompactBlockRepository` protocol
    ///  - backend: a class that complies to `ZcashRustBackendWelding`
    ///  - config: `Configuration` struct for this processor
    init(
        service: LightWalletService,
        storage: CompactBlockRepository,
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
    init(initializer: Initializer, walletBirthdayProvider: @escaping () -> BlockHeight) {
        self.init(
            service: initializer.lightWalletService,
            storage: initializer.storage,
            backend: initializer.rustBackend,
            config: Configuration(
                fsBlockCacheRoot: initializer.fsBlockDbRoot,
                dataDb: initializer.dataDbURL,
                spendParamsURL: initializer.spendParamsURL,
                outputParamsURL: initializer.outputParamsURL,
                saplingParamsSourceURL: initializer.saplingParamsSourceURL,
                walletBirthdayProvider: walletBirthdayProvider,
                network: initializer.network
            ),
            repository: initializer.transactionRepository,
            accountRepository: initializer.accountRepository
        )
    }
    
    internal init(
        service: LightWalletService,
        storage: CompactBlockRepository,
        backend: ZcashRustBackendWelding.Type,
        config: Configuration,
        repository: TransactionRepository,
        accountRepository: AccountRepository
    ) {
        let blockDownloaderService = BlockDownloaderServiceImpl(service: service, storage: storage)
        let blockDownloader = BlockDownloaderImpl(
            service: service,
            downloaderService: blockDownloaderService,
            storage: storage,
            internalSyncProgress: internalSyncProgress
        )

        self.blockDownloaderService = blockDownloaderService
        self.blockDownloader = blockDownloader

        let blockValidatorConfig = BlockValidatorConfig(
            fsBlockCacheRoot: config.fsBlockCacheRoot,
            dataDB: config.dataDb,
            networkType: config.network.networkType
        )
        self.blockValidator = BlockValidatorImpl(config: blockValidatorConfig, rustBackend: backend)

        let blockScannerConfig = BlockScannerConfig(
            fsBlockCacheRoot: config.fsBlockCacheRoot,
            dataDB: config.dataDb,
            networkType: config.network.networkType,
            scanningBatchSize: config.scanningBatchSize
        )
        self.blockScanner = BlockScannerImpl(config: blockScannerConfig, rustBackend: backend, transactionRepository: repository)

        let blockEnhancerConfig = BlockEnhancerConfig(dataDb: config.dataDb, networkType: config.network.networkType)
        self.blockEnhancer = BlockEnhancerImpl(
            blockDownloaderService: blockDownloaderService,
            config: blockEnhancerConfig,
            internalSyncProgress: internalSyncProgress,
            rustBackend: backend,
            transactionRepository: repository
        )

        let utxoFetcherConfig = UTXOFetcherConfig(
            dataDb: config.dataDb,
            networkType: config.network.networkType,
            walletBirthdayProvider: config.walletBirthdayProvider
        )
        self.utxoFetcher = UTXOFetcherImpl(
            accountRepository: accountRepository,
            blockDownloaderService: blockDownloaderService,
            config: utxoFetcherConfig,
            internalSyncProgress: internalSyncProgress,
            rustBackend: backend
        )

        let saplingParametersHandlerConfig = SaplingParametersHandlerConfig(
            dataDb: config.dataDb,
            networkType: config.network.networkType,
            outputParamsURL: config.outputParamsURL,
            spendParamsURL: config.spendParamsURL,
            saplingParamsSourceURL: config.saplingParamsSourceURL
        )
        self.saplingParametersHandler = SaplingParametersHandlerImpl(config: saplingParametersHandlerConfig, rustBackend: backend)

        self.service = service
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
    func start(retry: Bool = false) async {
        if retry {
            self.retryAttempts = 0
            self.processingError = nil
            self.backoffTimer?.invalidate()
            self.backoffTimer = nil
        }

        guard shouldStart else {
            switch self.state {
            case .error(let error):
                // max attempts have been reached
                LoggerProxy.info("max retry attempts reached with error: \(error)")
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
            case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
                LoggerProxy.debug("Warning: compact block processor was started while busy!!!!")
                afterSyncHooksManager.insert(hook: .anotherSync)
            }
            return
        }

        do {
            if let legacyCacheDbURL = self.config.cacheDbURL {
                try await self.migrateCacheDb(legacyCacheDbURL)
            }
        } catch {
            await self.fail(error)
        }

        await self.nextBatch()
    }

    /**
    Stops the CompactBlockProcessor

    Note: retry count is reset
    */
    func stop() {
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil

        cancelableTask?.cancel()

        self.retryAttempts = 0
    }

    // MARK: Rewind

    /// Rewinds to provided height.
    /// - Parameter height: height to rewind to. If nil is provided, it will rescan to nearest height (quick rescan)
    ///
    /// - Note: If this is called while sync is in progress then the sync process is stopped first and then rewind is executed.
    func rewind(context: AfterSyncHooksManager.RewindContext) async {
        LoggerProxy.debug("Starting rewid")
        switch self.state {
        case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
            LoggerProxy.debug("Stopping sync because of rewind")
            afterSyncHooksManager.insert(hook: .rewind(context))
            stop()

        case .stopped, .error, .synced:
            LoggerProxy.debug("Sync doesn't run. Executing rewind.")
            await doRewind(context: context)
        }
    }

    private func doRewind(context: AfterSyncHooksManager.RewindContext) async {
        LoggerProxy.debug("Executing rewind.")
        let lastDownloaded = await internalSyncProgress.latestDownloadedBlockHeight
        let height = Int32(context.height ?? lastDownloaded)
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
            return context.completion(.failure(error))
        }

        // FIXME: [#719] this should be done on the rust layer, https://github.com/zcash/ZcashLightClientKit/issues/719
        let rewindHeight = max(Int32(nearestHeight - 1), Int32(config.walletBirthday))
        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: rewindHeight, networkType: self.config.network.networkType) else {
            let error = rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)")
            await fail(error)
            return context.completion(.failure(error))
        }

        // clear cache
        let rewindBlockHeight = BlockHeight(rewindHeight)
        do {
            try blockDownloaderService.rewind(to: rewindBlockHeight)
        } catch {
            return context.completion(.failure(error))
        }

        await internalSyncProgress.rewind(to: rewindBlockHeight)

        self.lastChainValidationFailure = nil
        context.completion(.success(rewindBlockHeight))
    }

    // MARK: Wipe

    func wipe(context: AfterSyncHooksManager.WipeContext) async {
        LoggerProxy.debug("Starting wipe")
        switch self.state {
        case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
            LoggerProxy.debug("Stopping sync because of wipe")
            afterSyncHooksManager.insert(hook: .wipe(context))
            stop()

        case .stopped, .error, .synced:
            LoggerProxy.debug("Sync doesn't run. Executing wipe.")
            await doWipe(context: context)
        }
    }

    private func doWipe(context: AfterSyncHooksManager.WipeContext) async {
        LoggerProxy.debug("Executing wipe.")
        context.prewipe()

        state = .stopped

        do {
            try await self.storage.clear()
            await internalSyncProgress.rewind(to: 0)

            wipeLegacyCacheDbIfNeeded()

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: config.dataDb.path) {
                try fileManager.removeItem(at: config.dataDb)
            }

            if fileManager.fileExists(atPath: context.pendingDbURL.path) {
                try fileManager.removeItem(at: context.pendingDbURL)
            }

            context.completion(nil)
        } catch {
            context.completion(error)
        }
    }

    // MARK: Sync

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
                let totalProgressRange = computeTotalProgressRange(from: ranges)

                LoggerProxy.debug("""
                Syncing with ranges:
                downloaded but not scanned: \
                \(ranges.downloadedButUnscannedRange?.lowerBound ?? -1)...\(ranges.downloadedButUnscannedRange?.upperBound ?? -1)
                download and scan:          \(ranges.downloadAndScanRange?.lowerBound ?? -1)...\(ranges.downloadAndScanRange?.upperBound ?? -1)
                enhance range:              \(ranges.enhanceRange?.lowerBound ?? -1)...\(ranges.enhanceRange?.upperBound ?? -1)
                fetchUTXO range:            \(ranges.fetchUTXORange?.lowerBound ?? -1)...\(ranges.fetchUTXORange?.upperBound ?? -1)
                total progress range:       \(totalProgressRange.lowerBound)...\(totalProgressRange.upperBound)
                """)

                var anyActionExecuted = false

                // clear any present cached state if needed.
                // this checks if there was a sync in progress that was
                // interrupted abruptly and cache was not able to be cleared
                // properly and internal state set to the appropriate value
                if let newLatestDownloadedHeight = ranges.shouldClearBlockCacheAndUpdateInternalState() {
                    try await storage.clear()
                    await internalSyncProgress.set(newLatestDownloadedHeight, .latestDownloadedBlockHeight)
                } else {
                    try storage.create()
                }

                if let range = ranges.downloadedButUnscannedRange {
                    LoggerProxy.debug("Starting scan with downloaded but not scanned blocks with range: \(range.lowerBound)...\(range.upperBound)")
                    try await blockScanner.scanBlocks(at: range, totalProgressRange: totalProgressRange) { [weak self] lastScannedHeight in
                        let progress = BlockProgress(
                            startHeight: totalProgressRange.lowerBound,
                            targetHeight: totalProgressRange.upperBound,
                            progressHeight: lastScannedHeight
                        )
                        await self?.notifyProgress(.syncing(progress))
                    }
                }

                if let range = ranges.downloadAndScanRange {
                    LoggerProxy.debug("Starting sync with range: \(range.lowerBound)...\(range.upperBound)")
                    try await downloadAndScanBlocks(at: range, totalProgressRange: totalProgressRange)
                }

                if let range = ranges.enhanceRange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Enhancing with range: \(range.lowerBound)...\(range.upperBound)")
                    state = .enhancing
                    let transactions = try await blockEnhancer.enhance(at: range) { [weak self] progress in
                        await self?.notifyProgress(.enhance(progress))
                    }
                    notifyTransactions(transactions, in: range)
                }

                if let range = ranges.fetchUTXORange {
                    anyActionExecuted = true
                    LoggerProxy.debug("Fetching UTXO with range: \(range.lowerBound)...\(range.upperBound)")
                    state = .fetching
                    let result = try await utxoFetcher.fetch(at: range)
                    eventPublisher.send(.storedUTXOs(result))
                }

                LoggerProxy.debug("Fetching sapling parameters")
                state = .handlingSaplingFiles
                try await saplingParametersHandler.handleIfNeeded()

                LoggerProxy.debug("Clearing cache")
                try await clearCompactBlockCache()

                if !Task.isCancelled {
                    await processBatchFinished(height: anyActionExecuted ? ranges.latestBlockHeight : nil)
                }
            } catch {
                LoggerProxy.error("Sync failed with error: \(error)")

                if Task.isCancelled {
                    LoggerProxy.info("Processing cancelled.")
                    state = .stopped
                    await handleAfterSyncHooks()
                } else {
                    if case BlockValidatorError.validationFailed(let height) = error {
                        await validationFailed(at: height)
                    } else {
                        LoggerProxy.error("processing failed with error: \(error)")
                        await fail(error)
                    }
                }
            }
        }
    }

    private func handleAfterSyncHooks() async {
        let afterSyncHooksManager = self.afterSyncHooksManager
        self.afterSyncHooksManager = AfterSyncHooksManager()

        if let wipeContext = afterSyncHooksManager.shouldExecuteWipeHook() {
            await doWipe(context: wipeContext)
        } else if let rewindContext = afterSyncHooksManager.shouldExecuteRewindHook() {
            await doRewind(context: rewindContext)
        } else if afterSyncHooksManager.shouldExecuteAnotherSyncHook() {
            LoggerProxy.debug("Starting new sync.")
            await nextBatch()
        }
    }

    private func downloadAndScanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange) async throws {
        let downloadStream = try await blockDownloader.compactBlocksDownloadStream(
            startHeight: range.lowerBound,
            targetHeight: range.upperBound
        )

        // Divide `range` by `batchSize` and compute how many time do we need to run to download and scan all the blocks.
        // +1 must be done here becase `range` is closed range. So even if upperBound and lowerBound are same there is one block to sync.
        let blocksCountToSync = (range.upperBound - range.lowerBound) + 1
        var loopsCount = blocksCountToSync / batchSize
        if blocksCountToSync % batchSize != 0 {
            loopsCount += 1
        }

        for i in 0..<loopsCount {
            let processingRange = computeSingleLoopDownloadRange(fullRange: range, loopCounter: i, batchSize: batchSize)

            LoggerProxy.debug("Sync loop #\(i + 1) range: \(processingRange.lowerBound)...\(processingRange.upperBound)")

            try await blockDownloader.downloadAndStoreBlocks(
                using: downloadStream,
                at: processingRange,
                maxBlockBufferSize: config.downloadBufferSize,
                totalProgressRange: totalProgressRange
            )

            do {
                try await blockValidator.validate()
            } catch {
                guard let validationError = error as? BlockValidatorError else {
                    LoggerProxy.error("Block validation failed with generic error: \(error)")
                    throw error
                }

                switch validationError {
                case .validationFailed:
                    throw error

                case .failedWithError(let genericError):
                    throw genericError

                case .failedWithUnknownError:
                    LoggerProxy.error("validation failed without a specific error")
                    throw CompactBlockProcessorError.generalError(message: "validation failed without a specific error")
                }
            }

            do {
                try await blockScanner.scanBlocks(at: range, totalProgressRange: totalProgressRange) { [weak self] lastScannedHeight in
                    let progress = BlockProgress(
                        startHeight: totalProgressRange.lowerBound,
                        targetHeight: totalProgressRange.upperBound,
                        progressHeight: lastScannedHeight
                    )
                    await self?.notifyProgress(.syncing(progress))
                }
            } catch {
                LoggerProxy.error("Scanning failed with error: \(error)")
                throw error
            }

            try await clearCompactBlockCache()

            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: processingRange.upperBound
            )
            notifyProgress(.syncing(progress))
        }
    }

    /*
    Here range for one batch is computed. For example if we want to sync blocks 0...1000 with batchSize 100 we want to generage blocks like
    this:
    0...99
    100...199
    200...299
    300...399
    ...
    900...999
    1000...1000
    */
    func computeSingleLoopDownloadRange(fullRange: CompactBlockRange, loopCounter: Int, batchSize: BlockHeight) -> CompactBlockRange {
        let lowerBound = fullRange.lowerBound + (loopCounter * batchSize)
        let upperBound = min(fullRange.lowerBound + ((loopCounter + 1) * batchSize) - 1, fullRange.upperBound)
        return lowerBound...upperBound
    }

    /// It may happen that sync process start with syncing blocks that were downloaded but not synced in previous run of the sync process. This
    /// methods analyses what must be done and computes range that should be used to compute reported progress.
    private func computeTotalProgressRange(from syncRanges: SyncRanges) -> CompactBlockRange {
        guard syncRanges.downloadedButUnscannedRange != nil || syncRanges.downloadAndScanRange != nil else {
            // In this case we are sure that no downloading or scanning happens so this returned range won't be even used. And it's easier to return
            // this "fake" range than to handle nil.
            return 0...0
        }

        // Thanks to guard above we can be sure that one of these two ranges is not nil.
        let lowerBound = syncRanges.downloadedButUnscannedRange?.lowerBound ?? syncRanges.downloadAndScanRange?.lowerBound ?? 0
        let upperBound = syncRanges.downloadAndScanRange?.upperBound ?? syncRanges.downloadedButUnscannedRange?.upperBound ?? 0

        return lowerBound...upperBound
    }

    func notifyProgress(_ progress: CompactBlockProgress) {
        LoggerProxy.debug("progress: \(progress)")
        eventPublisher.send(.progressUpdated(progress))
    }
    
    func notifyTransactions(_ txs: [ZcashTransaction.Overview], in range: CompactBlockRange) {
        eventPublisher.send(.foundTransactions(txs, range))
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
        // TODO: [#713] specify: failure. https://github.com/zcash/ZcashLightClientKit/issues/713
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
        }
        return .unspecifiedError(underlyingError: error)
    }

    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.fsBlockCacheRoot.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.fsBlockCacheRoot.absoluteString)
        }

        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw CompactBlockProcessorError.missingDbPath(path: config.dataDb.absoluteString)
        }
    }

    private func nextBatch() async {
        state = .syncing
        do {
            let nextState = try await NextStateHelper.nextStateAsync(
                service: self.service,
                downloaderService: blockDownloaderService,
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
        
        // rewind
        let rewindHeight = determineLowerBound(
            errorHeight: height,
            consecutiveErrors: consecutiveChainValidationErrors,
            walletBirthday: self.config.walletBirthday
        )

        self.consecutiveChainValidationErrors += 1

        guard rustBackend.rewindToHeight(dbData: config.dataDb, height: Int32(rewindHeight), networkType: self.config.network.networkType) else {
            await fail(rustBackend.lastError() ?? RustWeldingError.genericError(message: "unknown error rewinding to height \(height)"))
            return
        }
        
        do {
            try blockDownloaderService.rewind(to: rewindHeight)
            await internalSyncProgress.rewind(to: rewindHeight)

            eventPublisher.send(.handledReorg(height, rewindHeight))

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
        eventPublisher.send(.finished(height, foundBlocks))
        state = .synced
        await setTimer()
    }

    private func clearCompactBlockCache() async throws {
        try await storage.clear()
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
                    guard let self else { return }
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

        switch newValue {
        case .error(let err):
            notifyError(err)
        case .stopped:
            eventPublisher.send(.stopped)
        case .enhancing:
            eventPublisher.send(.startedEnhancing)
        case .fetching:
            eventPublisher.send(.startedFetching)
        case .handlingSaplingFiles:
            // We don't report this to outside world as separate phase for now.
            break
        case .synced:
            // transition to this state is handled by `processingFinished(height: BlockHeight)`
            break
        case .syncing:
            eventPublisher.send(.startedSyncing)
        }
    }

    private func notifyError(_ err: Error) {
        eventPublisher.send(.failed(mapError(err)))
    }
    // TODO: [#713] encapsulate service errors better, https://github.com/zcash/ZcashLightClientKit/issues/713
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
            (.syncing, .syncing),
            (.stopped, .stopped),
            (.error, .error),
            (.synced, .synced),
            (.enhancing, .enhancing),
            (.fetching, .fetching):
            return true
        default:
            return false
        }
    }
}

extension CompactBlockProcessor {
    func getUnifiedAddress(accountIndex: Int) -> UnifiedAddress? {
        try? rustBackend.getCurrentAddress(
            dbData: config.dataDb,
            account: Int32(accountIndex),
            networkType: config.network.networkType
        )
    }
    
    func getSaplingAddress(accountIndex: Int) -> SaplingAddress? {
        getUnifiedAddress(accountIndex: accountIndex)?.saplingReceiver()
    }
    
    func getTransparentAddress(accountIndex: Int) -> TransparentAddress? {
        getUnifiedAddress(accountIndex: accountIndex)?.transparentReceiver()
    }
    
    func getTransparentBalance(accountIndex: Int) throws -> WalletBalance {
        guard accountIndex >= 0 else {
            throw CompactBlockProcessorError.invalidAccount
        }

        return WalletBalance(
            verified: Zatoshi(
                try rustBackend.getVerifiedTransparentBalance(
                    dbData: config.dataDb,
                    account: Int32(accountIndex),
                    networkType: config.network.networkType
                )
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
        
        let stream: AsyncThrowingStream<UnspentTransactionOutputEntity, Error> = blockDownloaderService.fetchUnspentTransactionOutputs(
            tAddress: tAddress.stringEncoded,
            startHeight: startHeight
        )
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
                if try self.rustBackend.putUnspentTransparentOutput(
                    dbData: dataDb,
                    txid: utxo.txid.bytes,
                    index: utxo.index,
                    script: utxo.script.bytes,
                    value: Int64(utxo.valueZat),
                    height: utxo.height,
                    networkType: self.config.network.networkType
                ) {
                    refreshed.append(utxo)
                } else {
                    skipped.append(utxo)
                }
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
            return """
            A server was reached, but it's targeting the wrong network Type. App Expected \(expected) but found \(found). Make sure you are pointing \
            to the right server
            """
        case let .saplingActivationMismatch(expected, found):
            return """
            A server was reached, it's showing a different sapling activation. App expected sapling activation height to be \(expected) but instead \
            it found \(found). Are you sure you are pointing to the right server?
            """
        case .unspecifiedError(let underlyingError):
            return "Unspecified error caused by this underlying error: \(underlyingError)"
        case let .wrongConsensusBranchId(expectedLocally, found):
            return """
            The remote server you are connecting to is publishing a different branch ID \(found) than the one your App is expecting to \
            be (\(expectedLocally)). This could be caused by your App being out of date or the server you are connecting you being either on a \
            different network or out of date after a network upgrade.
            """
        case .unknown: return "Unknown error occured."
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

extension CompactBlockProcessor {
    enum NextState: Equatable {
        case finishProcessing(height: BlockHeight)
        case processNewBlocks(ranges: SyncRanges)
        case wait(latestHeight: BlockHeight, latestDownloadHeight: BlockHeight)
    }

    @discardableResult
    func figureNextBatch(
        downloaderService: BlockDownloaderService
    ) async throws -> NextState {
        try Task.checkCancellation()

        do {
            return try await CompactBlockProcessor.NextStateHelper.nextStateAsync(
                service: service,
                downloaderService: downloaderService,
                transactionRepository: transactionRepository,
                config: config,
                rustBackend: rustBackend,
                internalSyncProgress: internalSyncProgress
            )
        } catch {
            throw error
        }
    }
}

extension CompactBlockProcessor {
    enum NextStateHelper {
        // swiftlint:disable:next function_parameter_count
        static func nextStateAsync(
            service: LightWalletService,
            downloaderService: BlockDownloaderService,
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

                let latestDownloadHeight = try downloaderService.lastDownloadedBlockHeight()

                await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadHeight)

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

/// This extension contains asociated types and functions needed to clean up the
/// `cacheDb` in favor of `FsBlockDb`. Once this cleanup functionality is deprecated,
/// delete the whole extension and reference to it in other parts of the code including tests.
extension CompactBlockProcessor {
    public enum CacheDbMigrationError: Error {
        case fsCacheMigrationFailedSameURL
        case failedToDeleteLegacyDb(Error)
        case failedToInitFsBlockDb(Error)
        case failedToSetDownloadHeight(Error)
    }

    /// Deletes the SQLite cacheDb and attempts to initialize the fsBlockDbRoot
    /// - parameter legacyCacheDbURL: the URL where the cache Db used to be stored.
    /// - Throws `InitializerError.fsCacheInitFailedSameURL` when the given URL
    /// is the same URL than the one provided as `self.fsBlockDbRoot` assuming that's a
    /// programming error being the `legacyCacheDbURL` a sqlite database file and not a
    /// directory. Also throws errors from initializing the fsBlockDbRoot.
    ///
    /// - Note: Errors from deleting the `legacyCacheDbURL` won't be throwns.
    func migrateCacheDb(_ legacyCacheDbURL: URL) async throws {
        guard legacyCacheDbURL != config.fsBlockCacheRoot else {
            throw CacheDbMigrationError.fsCacheMigrationFailedSameURL
        }

        // if the URL provided is not readable, it means that the client has a reference
        // to the cacheDb file but it has been deleted in a prior sync cycle. there's
        // nothing to do here.
        guard FileManager.default.isReadableFile(atPath: legacyCacheDbURL.path) else {
            return
        }

        do {
            // if there's a readable file at the provided URL, delete it.
            try FileManager.default.removeItem(at: legacyCacheDbURL)
        } catch {
            throw CacheDbMigrationError.failedToDeleteLegacyDb(error)
        }

        // create the storage
        do {
            try self.storage.create()
        } catch {
            throw CacheDbMigrationError.failedToInitFsBlockDb(error)
        }

        // The database has been deleted, so we have adjust the internal state of the
        // `CompactBlockProcessor` so that it doesn't rely on download heights set
        // by a previous processing cycle.
        do {
            let lastScannedHeight = try self.transactionRepository.lastScannedHeight()

            await internalSyncProgress.set(lastScannedHeight, .latestDownloadedBlockHeight)
        } catch {
            throw CacheDbMigrationError.failedToSetDownloadHeight(error)
        }
    }

    func wipeLegacyCacheDbIfNeeded() {
        guard let cacheDbURL = config.cacheDbURL else {
            return
        }

        guard FileManager.default.isDeletableFile(atPath: cacheDbURL.pathExtension) else {
            return
        }

        try? FileManager.default.removeItem(at: cacheDbURL)
    }
}

extension SyncRanges {
    /// Tells whether the state represented by these sync ranges evidence some sort of
    /// outdated state on the cache or the internal state of the compact block processor.
    ///
    /// - Note: this can mean that the processor has synced over the height that the internal
    /// state knows of because the sync process was interrupted before it could reflect
    /// it in the internal state storage. This could happen because of many factors, the
    /// most feasible being OS shutting down a background process or the user abruptly
    /// exiting the app.
    /// - Returns: an ``Optional<BlockHeight>`` where Some represents what's the
    /// new state the internal state should reflect and indicating that the cache should be cleared
    /// as well. c`None` means that no action is required.
    func shouldClearBlockCacheAndUpdateInternalState() -> BlockHeight? {
        guard self.downloadedButUnscannedRange != nil else {
            return nil
        }

        guard
            let latestScannedHeight = self.latestScannedHeight,
            let latestDownloadedHeight = self.latestDownloadedBlockHeight,
            latestScannedHeight > latestDownloadedHeight
        else { return nil }

        return latestScannedHeight
    }
}
