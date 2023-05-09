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

public enum CompactBlockProgress {
    case syncing(_ progress: BlockProgress)
    case enhance(_ progress: EnhancementProgress)
    case fetch(_ progress: Float)

    public var progress: Float {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.progress
        case .enhance(let enhancementProgress):
            return enhancementProgress.progress
        case .fetch(let fetchingProgress):
            return fetchingProgress
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
    public let totalTransactions: Int
    public let enhancedTransactions: Int
    public let lastFoundTransaction: ZcashTransaction.Overview?
    public let range: CompactBlockRange

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
    typealias EventClosure = (Event) async -> Void

    enum Event {
        /// Event sent when the CompactBlockProcessor presented an error.
        case failed (Error)

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
        let alias: ZcashSynchronizerAlias
        let saplingParamsSourceURL: SaplingParamsSourceURL
        let fsBlockCacheRoot: URL
        let dataDb: URL
        let spendParamsURL: URL
        let outputParamsURL: URL
        let downloadBatchSize: Int
        let scanningBatchSize: Int
        let retries: Int
        let maxBackoffInterval: TimeInterval
        let maxReorgSize = ZcashSDK.maxReorgSize
        let rewindDistance: Int
        let walletBirthdayProvider: () -> BlockHeight
        var walletBirthday: BlockHeight { walletBirthdayProvider() }
        let downloadBufferSize: Int = 10
        let network: ZcashNetwork
        let saplingActivation: BlockHeight
        let cacheDbURL: URL?
        var blockPollInterval: TimeInterval {
            TimeInterval.random(in: ZcashSDK.defaultPollInterval / 2 ... ZcashSDK.defaultPollInterval * 1.5)
        }
        
        init(
            alias: ZcashSynchronizerAlias,
            cacheDbURL: URL? = nil,
            fsBlockCacheRoot: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            saplingParamsSourceURL: SaplingParamsSourceURL,
            downloadBatchSize: Int = ZcashSDK.DefaultDownloadBatch,
            retries: Int = ZcashSDK.defaultRetries,
            maxBackoffInterval: TimeInterval = ZcashSDK.defaultMaxBackOffInterval,
            rewindDistance: Int = ZcashSDK.defaultRewindDistance,
            scanningBatchSize: Int = ZcashSDK.DefaultScanningBatch,
            walletBirthdayProvider: @escaping () -> BlockHeight,
            saplingActivation: BlockHeight,
            network: ZcashNetwork
        ) {
            self.alias = alias
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
            self.scanningBatchSize = scanningBatchSize
            self.walletBirthdayProvider = walletBirthdayProvider
            self.saplingActivation = saplingActivation
            self.cacheDbURL = cacheDbURL
            assert(downloadBatchSize >= scanningBatchSize)
        }
        
        init(
            alias: ZcashSynchronizerAlias,
            fsBlockCacheRoot: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            saplingParamsSourceURL: SaplingParamsSourceURL,
            downloadBatchSize: Int = ZcashSDK.DefaultDownloadBatch,
            retries: Int = ZcashSDK.defaultRetries,
            maxBackoffInterval: TimeInterval = ZcashSDK.defaultMaxBackOffInterval,
            rewindDistance: Int = ZcashSDK.defaultRewindDistance,
            scanningBatchSize: Int = ZcashSDK.DefaultScanningBatch,
            walletBirthdayProvider: @escaping () -> BlockHeight,
            network: ZcashNetwork
        ) {
            self.alias = alias
            self.fsBlockCacheRoot = fsBlockCacheRoot
            self.dataDb = dataDb
            self.spendParamsURL = spendParamsURL
            self.outputParamsURL = outputParamsURL
            self.saplingParamsSourceURL = saplingParamsSourceURL
            self.walletBirthdayProvider = walletBirthdayProvider
            self.saplingActivation = network.constants.saplingActivationHeight
            self.network = network
            self.cacheDbURL = nil
            self.downloadBatchSize = downloadBatchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.scanningBatchSize = scanningBatchSize

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

    let metrics: SDKMetrics
    let logger: Logger
    
    /// Don't update this variable directly. Use `updateState()` method.
    var state: State = .stopped

    private(set) var config: Configuration

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

    // It would be better to use Combine here but Combine doesn't work great with async. When this runs regularly only one closure is stored here
    // and that is one provided by `SDKSynchronizer`. But while running tests more "subscribers" is required here. Therefore it's required to handle
    // more closures here.
    var eventClosures: [String: EventClosure] = [:]

    let blockDownloaderService: BlockDownloaderService
    let blockDownloader: BlockDownloader
    let blockValidator: BlockValidator
    let blockScanner: BlockScanner
    let blockEnhancer: BlockEnhancer
    let utxoFetcher: UTXOFetcher
    let saplingParametersHandler: SaplingParametersHandler
    private let latestBlocksDataProvider: LatestBlocksDataProvider

    let service: LightWalletService
    let storage: CompactBlockRepository
    let transactionRepository: TransactionRepository
    let accountRepository: AccountRepository
    let rustBackend: ZcashRustBackendWelding
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

    private let internalSyncProgress: InternalSyncProgress

    /// Initializes a CompactBlockProcessor instance
    /// - Parameters:
    ///  - service: concrete implementation of `LightWalletService` protocol
    ///  - storage: concrete implementation of `CompactBlockRepository` protocol
    ///  - backend: a class that complies to `ZcashRustBackendWelding`
    ///  - config: `Configuration` struct for this processor
    init(
        container: DIContainer,
        config: Configuration
    ) {
        self.init(
            container: container,
            config: config,
            accountRepository: AccountRepositoryBuilder.build(dataDbURL: config.dataDb, readOnly: true, logger: container.resolve(Logger.self))
        )
    }

    /// Initializes a CompactBlockProcessor instance from an Initialized object
    /// - Parameters:
    ///     - initializer: an instance that complies to CompactBlockDownloading protocol
    init(initializer: Initializer, walletBirthdayProvider: @escaping () -> BlockHeight) {
        self.init(
            container: initializer.container,
            config: Configuration(
                alias: initializer.alias,
                fsBlockCacheRoot: initializer.fsBlockDbRoot,
                dataDb: initializer.dataDbURL,
                spendParamsURL: initializer.spendParamsURL,
                outputParamsURL: initializer.outputParamsURL,
                saplingParamsSourceURL: initializer.saplingParamsSourceURL,
                walletBirthdayProvider: walletBirthdayProvider,
                network: initializer.network
            ),
            accountRepository: initializer.accountRepository
        )
    }
    
    internal init(
        container: DIContainer,
        config: Configuration,
        accountRepository: AccountRepository
    ) {
        Dependencies.setupCompactBlockProcessor(
            in: container,
            config: config,
            accountRepository: accountRepository
        )

        self.metrics = container.resolve(SDKMetrics.self)
        self.logger = container.resolve(Logger.self)
        self.latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        self.internalSyncProgress = container.resolve(InternalSyncProgress.self)
        self.blockDownloaderService = container.resolve(BlockDownloaderService.self)
        self.blockDownloader = container.resolve(BlockDownloader.self)
        self.blockValidator = container.resolve(BlockValidator.self)
        self.blockScanner = container.resolve(BlockScanner.self)
        self.blockEnhancer = container.resolve(BlockEnhancer.self)
        self.utxoFetcher = container.resolve(UTXOFetcher.self)
        self.saplingParametersHandler = container.resolve(SaplingParametersHandler.self)
        self.service = container.resolve(LightWalletService.self)
        self.rustBackend = container.resolve(ZcashRustBackendWelding.self)
        self.storage = container.resolve(CompactBlockRepository.self)
        self.config = config
        self.transactionRepository = container.resolve(TransactionRepository.self)
        self.accountRepository = accountRepository
    }
    
    deinit {
        cancelableTask?.cancel()
    }

    func update(config: Configuration) async {
        self.config = config
        await stop()
    }

    func updateState(_ newState: State) async -> Void {
        let oldState = state
        state = newState
        await transitionState(from: oldState, to: newState)
    }

    func updateEventClosure(identifier: String, closure: @escaping (Event) async -> Void) async {
        eventClosures[identifier] = closure
    }

    func send(event: Event) async {
        for item in eventClosures {
            await item.value(event)
        }
    }

    static func validateServerInfo(
        _ info: LightWalletdInfo,
        saplingActivation: BlockHeight,
        localNetwork: ZcashNetwork,
        rustBackend: ZcashRustBackendWelding
    ) async throws {
        // check network types
        guard let remoteNetworkType = NetworkType.forChainName(info.chainName) else {
            throw ZcashError.compactBlockProcessorChainName(info.chainName)
        }

        guard remoteNetworkType == localNetwork.networkType else {
            throw ZcashError.compactBlockProcessorNetworkMismatch(localNetwork.networkType, remoteNetworkType)
        }

        guard saplingActivation == info.saplingActivationHeight else {
            throw ZcashError.compactBlockProcessorSaplingActivationMismatch(saplingActivation, BlockHeight(info.saplingActivationHeight))
        }

        // check branch id
        let localBranch = try rustBackend.consensusBranchIdFor(height: Int32(info.blockHeight))

        guard let remoteBranchID = ConsensusBranchID.fromString(info.consensusBranchID) else {
            throw ZcashError.compactBlockProcessorConsensusBranchID
        }

        guard remoteBranchID == localBranch else {
            throw ZcashError.compactBlockProcessorWrongConsensusBranchId(localBranch, remoteBranchID)
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
                logger.info("max retry attempts reached with error: \(error)")
                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
                await updateState(.stopped)
            case .stopped:
                // max attempts have been reached
                logger.info("max retry attempts reached")
                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
            case .synced:
                // max attempts have been reached
                logger.warn("max retry attempts reached on synced state, this indicates malfunction")
                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
            case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
                logger.debug("Warning: compact block processor was started while busy!!!!")
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
    func stop() async {
        self.backoffTimer?.invalidate()
        self.backoffTimer = nil

        cancelableTask?.cancel()
        await blockDownloader.stopDownload()

        self.retryAttempts = 0
    }

    // MARK: Rewind

    /// Rewinds to provided height.
    /// - Parameter height: height to rewind to. If nil is provided, it will rescan to nearest height (quick rescan)
    ///
    /// - Note: If this is called while sync is in progress then the sync process is stopped first and then rewind is executed.
    func rewind(context: AfterSyncHooksManager.RewindContext) async {
        logger.debug("Starting rewind")
        switch self.state {
        case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
            logger.debug("Stopping sync because of rewind")
            afterSyncHooksManager.insert(hook: .rewind(context))
            await stop()

        case .stopped, .error, .synced:
            logger.debug("Sync doesn't run. Executing rewind.")
            await doRewind(context: context)
        }
    }

    private func doRewind(context: AfterSyncHooksManager.RewindContext) async {
        logger.debug("Executing rewind.")
        let lastDownloaded = await internalSyncProgress.latestDownloadedBlockHeight
        let height = Int32(context.height ?? lastDownloaded)

        let nearestHeight: Int32
        do {
            nearestHeight = try await rustBackend.getNearestRewindHeight(height: height)
        } catch {
            await fail(error)
            return await context.completion(.failure(error))
        }

        // FIXME: [#719] this should be done on the rust layer, https://github.com/zcash/ZcashLightClientKit/issues/719
        let rewindHeight = max(Int32(nearestHeight - 1), Int32(config.walletBirthday))

        do {
            try await rustBackend.rewindToHeight(height: rewindHeight)
        } catch {
            await fail(error)
            return await context.completion(.failure(error))
        }

        // clear cache
        let rewindBlockHeight = BlockHeight(rewindHeight)
        do {
            try await blockDownloaderService.rewind(to: rewindBlockHeight)
        } catch {
            return await context.completion(.failure(error))
        }

        await internalSyncProgress.rewind(to: rewindBlockHeight)

        self.lastChainValidationFailure = nil
        await context.completion(.success(rewindBlockHeight))
    }

    // MARK: Wipe

    func wipe(context: AfterSyncHooksManager.WipeContext) async {
        logger.debug("Starting wipe")
        switch self.state {
        case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
            logger.debug("Stopping sync because of wipe")
            afterSyncHooksManager.insert(hook: .wipe(context))
            await stop()

        case .stopped, .error, .synced:
            logger.debug("Sync doesn't run. Executing wipe.")
            await doWipe(context: context)
        }
    }

    private func doWipe(context: AfterSyncHooksManager.WipeContext) async {
        logger.debug("Executing wipe.")
        context.prewipe()

        await updateState(.stopped)

        do {
            try await self.storage.clear()
            await internalSyncProgress.rewind(to: 0)

            wipeLegacyCacheDbIfNeeded()

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: config.dataDb.path) {
                try fileManager.removeItem(at: config.dataDb)
            }

            await context.completion(nil)
        } catch {
            await context.completion(error)
        }
    }

    // MARK: Sync

    func validateServer() async {
        do {
            let info = try await self.service.getInfo()
            try await Self.validateServerInfo(
                info,
                saplingActivation: self.config.saplingActivation,
                localNetwork: self.config.network,
                rustBackend: self.rustBackend
            )
        } catch {
            await self.severeFailure(error)
        }
    }
    
    /// Processes new blocks on the given range based on the configuration set for this instance
    func processNewBlocks(ranges: SyncRanges) async {
        self.foundBlocks = true
        
        cancelableTask = Task(priority: .userInitiated) {
            do {
                let totalProgressRange = computeTotalProgressRange(from: ranges)

                logger.debug("""
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
                    try await storage.create()
                }

                if let range = ranges.downloadedButUnscannedRange {
                    logger.debug("Starting scan with downloaded but not scanned blocks with range: \(range.lowerBound)...\(range.upperBound)")
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
                    logger.debug("Starting sync with range: \(range.lowerBound)...\(range.upperBound)")
                    try await blockDownloader.setSyncRange(range)
                    try await downloadAndScanBlocks(at: range, totalProgressRange: totalProgressRange)
                }

                if let range = ranges.enhanceRange {
                    anyActionExecuted = true
                    logger.debug("Enhancing with range: \(range.lowerBound)...\(range.upperBound)")
                    await updateState(.enhancing)
                    let transactions = try await blockEnhancer.enhance(at: range) { [weak self] progress in
                        await self?.notifyProgress(.enhance(progress))
                    }
                    await notifyTransactions(transactions, in: range)
                }

                if let range = ranges.fetchUTXORange {
                    anyActionExecuted = true
                    logger.debug("Fetching UTXO with range: \(range.lowerBound)...\(range.upperBound)")
                    await updateState(.fetching)
                    let result = try await utxoFetcher.fetch(at: range) { [weak self] progress in
                        await self?.notifyProgress(.fetch(progress))
                    }
                    await send(event: .storedUTXOs(result))
                }

                logger.debug("Fetching sapling parameters")
                await updateState(.handlingSaplingFiles)
                try await saplingParametersHandler.handleIfNeeded()

                logger.debug("Clearing cache")
                try await clearCompactBlockCache()

                if !Task.isCancelled {
                    let newBlocksMined = await ranges.latestBlockHeight < latestBlocksDataProvider.latestBlockHeight
                    await processBatchFinished(height: (anyActionExecuted && !newBlocksMined) ? ranges.latestBlockHeight : nil)
                }
            } catch {
                logger.error("Sync failed with error: \(error)")

                if Task.isCancelled {
                    logger.info("Processing cancelled.")
                    await updateState(.stopped)
                    await handleAfterSyncHooks()
                } else {
                    if case let ZcashError.rustValidateCombinedChainInvalidChain(height) = error {
                        await validationFailed(at: BlockHeight(height))
                    } else {
                        logger.error("processing failed with error: \(error)")
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
            logger.debug("Starting new sync.")
            await nextBatch()
        }
    }

    private func downloadAndScanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange) async throws {
        // Divide `range` by `batchSize` and compute how many time do we need to run to download and scan all the blocks.
        // +1 must be done here becase `range` is closed range. So even if upperBound and lowerBound are same there is one block to sync.
        let blocksCountToSync = (range.upperBound - range.lowerBound) + 1
        var loopsCount = blocksCountToSync / batchSize
        if blocksCountToSync % batchSize != 0 {
            loopsCount += 1
        }

        var lastScannedHeight: BlockHeight = .zero
        for i in 0..<loopsCount {
            let processingRange = computeSingleLoopDownloadRange(fullRange: range, loopCounter: i, batchSize: batchSize)

            logger.debug("Sync loop #\(i + 1) range: \(processingRange.lowerBound)...\(processingRange.upperBound)")

            // This is important. We must be sure that no new download is executed when this Task is canceled. Without this line `stop()` doesn't
            // work.
            try Task.checkCancellation()

            do {
                await blockDownloader.setDownloadLimit(processingRange.upperBound + (2 * batchSize))
                await blockDownloader.startDownload(maxBlockBufferSize: config.downloadBufferSize)

                try await blockDownloader.waitUntilRequestedBlocksAreDownloaded(in: processingRange)
            } catch {
                await ifTaskIsNotCanceledClearCompactBlockCache(lastScannedHeight: lastScannedHeight)
                throw error
            }

            do {
                try await blockValidator.validate()
            } catch {
                await ifTaskIsNotCanceledClearCompactBlockCache(lastScannedHeight: lastScannedHeight)
                logger.error("Block validation failed with error: \(error)")
                throw error
            }

            // Without this `stop()` would work. But this line improves support for Task cancelation.
            try Task.checkCancellation()

            do {
                lastScannedHeight = try await blockScanner.scanBlocks(
                    at: processingRange,
                    totalProgressRange: totalProgressRange
                ) { [weak self] lastScannedHeight in
                    let progress = BlockProgress(
                        startHeight: totalProgressRange.lowerBound,
                        targetHeight: totalProgressRange.upperBound,
                        progressHeight: lastScannedHeight
                    )
                    await self?.notifyProgress(.syncing(progress))
                }
            } catch {
                logger.error("Scanning failed with error: \(error)")
                await ifTaskIsNotCanceledClearCompactBlockCache(lastScannedHeight: lastScannedHeight)
                throw error
            }

            try await clearCompactBlockCache(upTo: lastScannedHeight)

            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: processingRange.upperBound
            )
            await notifyProgress(.syncing(progress))
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

    func notifyProgress(_ progress: CompactBlockProgress) async {
        logger.debug("progress: \(progress)")
        await send(event: .progressUpdated(progress))
    }
    
    func notifyTransactions(_ txs: [ZcashTransaction.Overview], in range: CompactBlockRange) async {
        await send(event: .foundTransactions(txs, range))
    }

    func determineLowerBound(
        errorHeight: Int,
        consecutiveErrors: Int,
        walletBirthday: BlockHeight
    ) -> BlockHeight {
        let offset = min(ZcashSDK.maxReorgSize, ZcashSDK.defaultRewindDistance * (consecutiveErrors + 1))
        return max(errorHeight - offset, walletBirthday - ZcashSDK.maxReorgSize)
    }

    func severeFailure(_ error: Error) async {
        cancelableTask?.cancel()
        await blockDownloader.stopDownload()
        logger.error("show stopper failure: \(error)")
        self.backoffTimer?.invalidate()
        self.retryAttempts = config.retries
        self.processingError = error
        await updateState(.error(error))
        await self.notifyError(error)
    }

    func fail(_ error: Error) async {
        // TODO: [#713] specify: failure. https://github.com/zcash/ZcashLightClientKit/issues/713
        logger.error("\(error)")
        cancelableTask?.cancel()
        await blockDownloader.stopDownload()
        self.retryAttempts += 1
        self.processingError = error
        switch self.state {
        case .error:
            await notifyError(error)
        default:
            break
        }
        await updateState(.error(error))
        guard self.maxAttemptsReached else { return }
        // don't set a new timer if there are no more attempts.
        await self.setTimer()
    }

    private func validateConfiguration() throws {
        guard FileManager.default.isReadableFile(atPath: config.fsBlockCacheRoot.absoluteString) else {
            throw ZcashError.compactBlockProcessorMissingDbPath(config.fsBlockCacheRoot.absoluteString)
        }

        guard FileManager.default.isReadableFile(atPath: config.dataDb.absoluteString) else {
            throw ZcashError.compactBlockProcessorMissingDbPath(config.dataDb.absoluteString)
        }
    }

    private func nextBatch() async {
        await updateState(.syncing)
        if backoffTimer == nil { await setTimer() }
        do {
            let nextState = try await NextStateHelper.nextState(
                service: self.service,
                downloaderService: blockDownloaderService,
                latestBlocksDataProvider: latestBlocksDataProvider,
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
                logger.info(
                    "Lightwalletd might be syncing: latest downloaded block height is: \(latestDownloadHeight) " +
                    "while latest blockheight is reported at: \(latestHeight)"
                )
                await self.processingFinished(height: latestDownloadHeight)
            }
        } catch {
            await self.severeFailure(error)
        }
    }

    internal func validationFailed(at height: BlockHeight) async {
        // cancel all Tasks
        cancelableTask?.cancel()
        await blockDownloader.stopDownload()

        // register latest failure
        self.lastChainValidationFailure = height
        
        // rewind
        let rewindHeight = determineLowerBound(
            errorHeight: height,
            consecutiveErrors: consecutiveChainValidationErrors,
            walletBirthday: self.config.walletBirthday
        )

        self.consecutiveChainValidationErrors += 1

        do {
            try await rustBackend.rewindToHeight(height: Int32(rewindHeight))
        } catch {
            await fail(error)
            return
        }
        
        do {
            try await blockDownloaderService.rewind(to: rewindHeight)
            await internalSyncProgress.rewind(to: rewindHeight)

            await send(event: .handledReorg(height, rewindHeight))

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
        await send(event: .finished(height, foundBlocks))
        await updateState(.synced)
        await setTimer()
    }

    private func ifTaskIsNotCanceledClearCompactBlockCache(lastScannedHeight: BlockHeight) async {
        guard !Task.isCancelled else { return }
        do {
            // Blocks download work in parallel with scanning. So imagine this scenario:
            //
            // Scanning is done until height 10300. Blocks are downloaded until height 10400.
            // And now validation fails and this method is called. And `.latestDownloadedBlockHeight` in `internalSyncProgress` is set to 10400. And
            // all the downloaded blocks are removed here.
            //
            // If this line doesn't happen then when sync starts next time it thinks that all the blocks are downloaded until 10400. But all were
            // removed. So blocks between 10300 and 10400 wouldn't ever be scanned.
            //
            // Scanning is done until 10300 so the SDK can be sure that blocks with height below 10300 are not required. So it makes sense to set
            // `.latestDownloadedBlockHeight` to `lastScannedHeight`. And sync will work fine in next run.
            await internalSyncProgress.set(lastScannedHeight, .latestDownloadedBlockHeight)
            try await clearCompactBlockCache()
        } catch {
            logger.error("`clearCompactBlockCache` failed after error: \(error)")
        }
    }

    private func clearCompactBlockCache(upTo height: BlockHeight) async throws {
        try await storage.clear(upTo: height)
        logger.info("Cache removed upTo \(height)")
    }

    private func clearCompactBlockCache() async throws {
        await blockDownloader.stopDownload()
        try await storage.clear()
        logger.info("Cache removed")
    }
    
    private func setTimer() async {
        let interval = self.config.blockPollInterval
        self.backoffTimer?.invalidate()
        let timer = Timer(
            timeInterval: interval,
            repeats: true,
            block: { [weak self] _ in
                Task { [weak self] in
                    guard let self else { return }
                    switch await self.state {
                    case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
                        await self.latestBlocksDataProvider.updateBlockData()
                    case .stopped, .error, .synced:
                        if await self.shouldStart {
                            self.logger.debug(
                                """
                                Timer triggered: Starting compact Block processor!.
                                Processor State: \(await self.state)
                                latestHeight: \(try await self.transactionRepository.lastScannedHeight())
                                attempts: \(await self.retryAttempts)
                                """
                            )
                            await self.start()
                        } else if await self.maxAttemptsReached {
                            await self.fail(ZcashError.compactBlockProcessorMaxAttemptsReached(self.config.retries))
                        }
                    }
                }
            }
        )
        RunLoop.main.add(timer, forMode: .default)
        
        self.backoffTimer = timer
    }
    
    private func transitionState(from oldValue: State, to newValue: State) async {
        guard oldValue != newValue else {
            return
        }

        switch newValue {
        case .error(let err):
            await notifyError(err)
        case .stopped:
            await send(event: .stopped)
        case .enhancing:
            await send(event: .startedEnhancing)
        case .fetching:
            await send(event: .startedFetching)
        case .handlingSaplingFiles:
            // We don't report this to outside world as separate phase for now.
            break
        case .synced:
            // transition to this state is handled by `processingFinished(height: BlockHeight)`
            break
        case .syncing:
            await send(event: .startedSyncing)
        }
    }

    private func notifyError(_ err: Error) async {
        await send(event: .failed(err))
    }
    // TODO: [#713] encapsulate service errors better, https://github.com/zcash/ZcashLightClientKit/issues/713
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
    func getUnifiedAddress(accountIndex: Int) async throws -> UnifiedAddress {
        try await rustBackend.getCurrentAddress(account: Int32(accountIndex))
    }
    
    func getSaplingAddress(accountIndex: Int) async throws -> SaplingAddress {
        try await getUnifiedAddress(accountIndex: accountIndex).saplingReceiver()
    }
    
    func getTransparentAddress(accountIndex: Int) async throws -> TransparentAddress {
        try await getUnifiedAddress(accountIndex: accountIndex).transparentReceiver()
    }
    
    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance {
        guard accountIndex >= 0 else {
            throw ZcashError.compactBlockProcessorInvalidAccount
        }

        return WalletBalance(
            verified: Zatoshi(
                try await rustBackend.getVerifiedTransparentBalance(account: Int32(accountIndex))
            ),
            total: Zatoshi(
                try await rustBackend.getTransparentBalance(account: Int32(accountIndex))
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
            return await storeUTXOs(utxos, in: dataDb)
        } catch {
            throw error
        }
    }
    
    private func storeUTXOs(_ utxos: [UnspentTransactionOutputEntity], in dataDb: URL) async -> RefreshedUTXOs {
        var refreshed: [UnspentTransactionOutputEntity] = []
        var skipped: [UnspentTransactionOutputEntity] = []
        for utxo in utxos {
            do {
                try await rustBackend.putUnspentTransparentOutput(
                    txid: utxo.txid.bytes,
                    index: utxo.index,
                    script: utxo.script.bytes,
                    value: Int64(utxo.valueZat),
                    height: utxo.height
                )

                refreshed.append(utxo)
            } catch {
                logger.info("failed to put utxo - error: \(error)")
                skipped.append(utxo)
            }
        }
        return (inserted: refreshed, skipped: skipped)
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
            return try await CompactBlockProcessor.NextStateHelper.nextState(
                service: service,
                downloaderService: downloaderService,
                latestBlocksDataProvider: latestBlocksDataProvider,
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
        static func nextState(
            service: LightWalletService,
            downloaderService: BlockDownloaderService,
            latestBlocksDataProvider: LatestBlocksDataProvider,
            config: Configuration,
            rustBackend: ZcashRustBackendWelding,
            internalSyncProgress: InternalSyncProgress
        ) async throws -> CompactBlockProcessor.NextState {
            // It should be ok to not create new Task here because this method is already async. But for some reason something not good happens
            // when Task is not created here. For example tests start failing. Reason is unknown at this time.
            let task = Task(priority: .userInitiated) {
                let info = try await service.getInfo()

                try await CompactBlockProcessor.validateServerInfo(
                    info,
                    saplingActivation: config.saplingActivation,
                    localNetwork: config.network,
                    rustBackend: rustBackend
                )

                let latestDownloadHeight = try await downloaderService.lastDownloadedBlockHeight()

                await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadHeight)

                await latestBlocksDataProvider.updateScannedData()
                await latestBlocksDataProvider.updateBlockData()

                return await internalSyncProgress.computeNextState(
                    latestBlockHeight: latestBlocksDataProvider.latestBlockHeight,
                    latestScannedHeight: latestBlocksDataProvider.latestScannedHeight,
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
    /// - Throws: `InitializerError.fsCacheInitFailedSameURL` when the given URL
    /// is the same URL than the one provided as `self.fsBlockDbRoot` assuming that's a
    /// programming error being the `legacyCacheDbURL` a sqlite database file and not a
    /// directory. Also throws errors from initializing the fsBlockDbRoot.
    ///
    /// - Note: Errors from deleting the `legacyCacheDbURL` won't be throwns.
    func migrateCacheDb(_ legacyCacheDbURL: URL) async throws {
        guard legacyCacheDbURL != config.fsBlockCacheRoot else {
            throw ZcashError.compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL
        }

        // Instance with alias `default` is same as instance before the Alias was introduced. So it makes sense that only this instance handles
        // legacy cache DB. Any instance with different than `default` alias was created after the Alias was introduced and at this point legacy
        // cache DB is't anymore. So there is nothing to migrate for instances with not default Alias.
        guard config.alias == .default else {
            return
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
            throw ZcashError.compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb(error)
        }

        // create the storage
        try await self.storage.create()

        // The database has been deleted, so we have adjust the internal state of the
        // `CompactBlockProcessor` so that it doesn't rely on download heights set
        // by a previous processing cycle.
        let lastScannedHeight = try await transactionRepository.lastScannedHeight()
        
        await internalSyncProgress.set(lastScannedHeight, .latestDownloadedBlockHeight)
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
