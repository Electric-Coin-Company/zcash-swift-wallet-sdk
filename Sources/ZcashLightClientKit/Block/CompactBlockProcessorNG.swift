//
//  CompactBlockProcessor.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class CompactBlockProcessorNG {
    // It would be better to use Combine here but Combine doesn't work great with async. When this runs regularly only one closure is stored here
    // and that is one provided by `SDKSynchronizer`. But while running tests more "subscribers" is required here. Therefore it's required to handle
    // more closures here.
    private var eventClosures: [String: EventClosure] = [:]

    private var syncTask: Task<Void, Error>?

    private let actions: [CBPState: Action]
    private var context: ActionContext

    private let metrics: SDKMetrics
    private let blockDownloaderService: BlockDownloaderService
    private let latestBlocksDataProvider: LatestBlocksDataProvider
    private let service: LightWalletService
    private let storage: CompactBlockRepository
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let rustBackend: ZcashRustBackendWelding
    private let logger: Logger
    private let internalSyncProgress: InternalSyncProgress

    private(set) var config: Configuration

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
        let batchSize: Int
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
            batchSize: Int = ZcashSDK.DefaultSyncBatch,
            retries: Int = ZcashSDK.defaultRetries,
            maxBackoffInterval: TimeInterval = ZcashSDK.defaultMaxBackOffInterval,
            rewindDistance: Int = ZcashSDK.defaultRewindDistance,
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
            self.batchSize = batchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
            self.walletBirthdayProvider = walletBirthdayProvider
            self.saplingActivation = saplingActivation
            self.cacheDbURL = cacheDbURL
        }

        init(
            alias: ZcashSynchronizerAlias,
            fsBlockCacheRoot: URL,
            dataDb: URL,
            spendParamsURL: URL,
            outputParamsURL: URL,
            saplingParamsSourceURL: SaplingParamsSourceURL,
            batchSize: Int = ZcashSDK.DefaultSyncBatch,
            retries: Int = ZcashSDK.defaultRetries,
            maxBackoffInterval: TimeInterval = ZcashSDK.defaultMaxBackOffInterval,
            rewindDistance: Int = ZcashSDK.defaultRewindDistance,
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
            self.batchSize = batchSize
            self.retries = retries
            self.maxBackoffInterval = maxBackoffInterval
            self.rewindDistance = rewindDistance
        }
    }

    /// Initializes a CompactBlockProcessor instance
    /// - Parameters:
    ///  - service: concrete implementation of `LightWalletService` protocol
    ///  - storage: concrete implementation of `CompactBlockRepository` protocol
    ///  - backend: a class that complies to `ZcashRustBackendWelding`
    ///  - config: `Configuration` struct for this processor
    convenience init(container: DIContainer, config: Configuration) {
        self.init(
            container: container,
            config: config,
            accountRepository: AccountRepositoryBuilder.build(dataDbURL: config.dataDb, readOnly: true, logger: container.resolve(Logger.self))
        )
    }

    /// Initializes a CompactBlockProcessor instance from an Initialized object
    /// - Parameters:
    ///     - initializer: an instance that complies to CompactBlockDownloading protocol
    convenience init(initializer: Initializer, walletBirthdayProvider: @escaping () -> BlockHeight) {
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

    internal init(container: DIContainer, config: Configuration, accountRepository: AccountRepository) {
//        Dependencies.setupCompactBlockProcessor(
//            in: container,
//            config: config,
//            accountRepository: accountRepository
//        )

        context = ActionContext(state: .validateServer)
        actions = Self.makeActions(container: container, config: config)
        
        self.metrics = container.resolve(SDKMetrics.self)
        self.logger = container.resolve(Logger.self)
        self.latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        self.internalSyncProgress = container.resolve(InternalSyncProgress.self)
        self.blockDownloaderService = container.resolve(BlockDownloaderService.self)
        self.service = container.resolve(LightWalletService.self)
        self.rustBackend = container.resolve(ZcashRustBackendWelding.self)
        self.storage = container.resolve(CompactBlockRepository.self)
        self.config = config
        self.transactionRepository = container.resolve(TransactionRepository.self)
        self.accountRepository = accountRepository
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func makeActions(container: DIContainer, config: Configuration) -> [CBPState: Action] {
        let actionsDefinition = CBPState.allCases.compactMap { state -> (CBPState, Action)? in
            let action: Action
            switch state {
            case .validateServer:
                action = ValidateServerAction(container: container, config: config)
            case .computeSyncRanges:
                action = ComputeSyncRangesAction(container: container)
            case .checksBeforeSync:
                action = ChecksBeforeSyncAction(container: container)
            case .scanDownloaded:
                action = ScanDownloadedButUnscannedAction(container: container)
            case .download:
                action = DownloadAction(container: container, config: config)
            case .validate:
                action = ValidateAction(container: container)
            case .scan:
                action = ScanAction(container: container)
            case .clearAlreadyScannedBlocks:
                action = ClearAlreadyScannedBlocksAction(container: container)
            case .enhance:
                action = EnhanceAction(container: container)
            case .fetchUTXO:
                action = FetchUTXOsAction(container: container)
            case .handleSaplingParams:
                action = SaplingParamsAction(container: container)
            case .clearCache:
                action = ClearCacheAction(container: container)
            case .finished, .failed, .stopped:
                return nil
            }

            return (state, action)
        }

        return Dictionary(uniqueKeysWithValues: actionsDefinition)
    }
}

// MARK: - "Public" API

extension CompactBlockProcessorNG {
    func start(retry: Bool = false) async {
//        if retry {
//            self.retryAttempts = 0
//            self.processingError = nil
//            self.backoffTimer?.invalidate()
//            self.backoffTimer = nil
//        }

        guard await canStartSync() else {
            //            switch self.state {
            //            case .error(let error):
            //                // max attempts have been reached
            //                logger.info("max retry attempts reached with error: \(error)")
            //                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
            //                await updateState(.stopped)
            //            case .stopped:
            //                // max attempts have been reached
            //                logger.info("max retry attempts reached")
            //                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
            //            case .synced:
            //                // max attempts have been reached
            //                logger.warn("max retry attempts reached on synced state, this indicates malfunction")
            //                await notifyError(ZcashError.compactBlockProcessorMaxAttemptsReached(self.maxAttempts))
            //            case .syncing, .enhancing, .fetching, .handlingSaplingFiles:
            //                logger.debug("Warning: compact block processor was started while busy!!!!")
            //                afterSyncHooksManager.insert(hook: .anotherSync)
            //            }
            //            return
            return
        }

        //
        //        do {
        //            if let legacyCacheDbURL = self.config.cacheDbURL {
        //                try await self.migrateCacheDb(legacyCacheDbURL)
        //            }
        //        } catch {
        //            await self.fail(error)
        //        }


        syncTask = Task(priority: .userInitiated) {
            await run()
        }
    }

    func stop() {
        syncTask?.cancel()
//        self.backoffTimer?.invalidate()
//        self.backoffTimer = nil
//
//        cancelableTask?.cancel()
//
//        self.retryAttempts = 0
    }

}

// MARK: - Events

extension CompactBlockProcessorNG {
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

    func updateEventClosure(identifier: String, closure: @escaping (Event) async -> Void) async {
        eventClosures[identifier] = closure
    }

    func send(event: Event) async {
        for item in eventClosures {
            await item.value(event)
        }
    }
}

// MARK: - Main loop

extension CompactBlockProcessorNG {
    // This is main loop of the sync process. It simply takes state and try to find action which handles it. If action is found it executes the
    // action. If action is not found then loop finishes. Thanks to this it's super easy to identify start point of sync process and end points
    // of sync process without any side effects.
    func run() async {
        // Prepare for sync and set everything to default values.
        await context.update(state: .validateServer)
        await syncStarted()

        // Try to find action for state.
        while true {
            guard let action = actions[await context.state] else {
                await syncFinished()
                break
            }

            do {
                try Task.checkCancellation()
                // Execute action.
                context = try await action.run(with: context) { [weak self] progress in
                    await self?.update(progress: progress)
                }
            } catch {
                logger.error("Sync failed with error: \(error)")

                if Task.isCancelled {
                    logger.info("Processing cancelled.")
                    await syncStopped()
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

    func syncStarted() async {
        // handle start of the sync process
        await send(event: .startedSyncing)
    }

    func syncFinished() async {
        // handle finish of the sync
        //        await send(event: .finished(<#T##lastScannedHeight: BlockHeight##BlockHeight#>, <#T##foundBlocks: Bool##Bool#>))
    }

    func update(progress: ActionProgress) async {
        // handle update of the progree
    }

    func syncStopped() async {
        await context.update(state: .stopped)
        await send(event: .stopped)
        // await handleAfterSyncHooks()
    }

    func validationFailed(at height: BlockHeight) async {
        // handle validation failure
    }

    func fail(_ error: Error) async {
        // handle failure
    }
}

// MARK: - Utils

extension CompactBlockProcessorNG {
    func canStartSync() async -> Bool {
        switch await context.state {
        case .stopped, .failed, .finished, .validateServer:
            return true
        case .computeSyncRanges, .checksBeforeSync, .download, .validate, .scan, .enhance, .fetchUTXO, .handleSaplingParams, .clearCache,
                .scanDownloaded, .clearAlreadyScannedBlocks:
            return false
        }
    }
}
