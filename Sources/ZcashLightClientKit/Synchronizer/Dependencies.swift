//
//  Dependencies.swift
//  
//
//  Created by Michal Fousek on 01.05.2023.
//

import Foundation

enum Dependencies {
    static func setup(
        in container: DIContainer,
        urls: Initializer.URLs,
        alias: ZcashSynchronizerAlias,
        networkType: NetworkType,
        endpoint: LightWalletEndpoint,
        loggingPolicy: Initializer.LoggingPolicy = .default(.debug)
    ) {
        container.register(type: Logger.self, isSingleton: true) { _ in
            let logger: Logger
            switch loggingPolicy {
            case let .default(logLevel):
                logger = OSLogger(logLevel: logLevel, alias: alias)
            case let .custom(customLogger):
                logger = customLogger
            case .noLogging:
                logger = NullLogger()
            }

            return logger
        }

        container.register(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in
            return ZcashRustBackend(
                dbData: urls.dataDbURL,
                fsBlockDbRoot: urls.fsBlockDbRoot,
                spendParamsPath: urls.spendParamsURL,
                outputParamsPath: urls.outputParamsURL,
                networkType: networkType
            )
        }

        container.register(type: LightWalletService.self, isSingleton: true) { _ in
            return LightWalletGRPCService(endpoint: endpoint)
        }

        container.register(type: TransactionRepository.self, isSingleton: true) { _ in
            TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: urls.dataDbURL.path, readonly: true))
        }

        container.register(type: CompactBlockRepository.self, isSingleton: true) { di in
            let logger = di.resolve(Logger.self)
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)

            return FSCompactBlockRepository(
                fsBlockDbRoot: urls.fsBlockDbRoot,
                metadataStore: .live(
                    fsBlockDbRoot: urls.fsBlockDbRoot,
                    rustBackend: rustBackend,
                    logger: logger
                ),
                blockDescriptor: .live,
                contentProvider: DirectoryListingProviders.defaultSorted,
                logger: logger
            )
        }

        container.register(type: BlockDownloaderService.self, isSingleton: true) { di in
            let service = di.resolve(LightWalletService.self)
            let storage = di.resolve(CompactBlockRepository.self)

            return BlockDownloaderServiceImpl(service: service, storage: storage)
        }

        container.register(type: SDKMetrics.self, isSingleton: true) { _ in
            SDKMetrics()
        }

        container.register(type: LatestBlocksDataProvider.self, isSingleton: true) { di in
            let service = di.resolve(LightWalletService.self)
            let transactionRepository = di.resolve(TransactionRepository.self)

            return LatestBlocksDataProviderImpl(service: service, transactionRepository: transactionRepository)
        }

        container.register(type: SyncSessionIDGenerator.self, isSingleton: false) { _ in
            UniqueSyncSessionIDGenerator()
        }

        container.register(type: InternalSyncProgress.self, isSingleton: true) { di in
            let logger = di.resolve(Logger.self)
            return InternalSyncProgress(alias: alias, storage: UserDefaults.standard, logger: logger)
        }
    }
    
    static func setupCompactBlockProcessor(
        in container: DIContainer,
        config: CompactBlockProcessor.Configuration,
        accountRepository: AccountRepository
    ) {
        container.register(type: BlockDownloader.self, isSingleton: true) { di in
            let service = di.resolve(LightWalletService.self)
            let blockDownloaderService = di.resolve(BlockDownloaderService.self)
            let storage = di.resolve(CompactBlockRepository.self)
            let internalSyncProgress = di.resolve(InternalSyncProgress.self)
            let metrics = di.resolve(SDKMetrics.self)
            let logger = di.resolve(Logger.self)

            return BlockDownloaderImpl(
                service: service,
                downloaderService: blockDownloaderService,
                storage: storage,
                internalSyncProgress: internalSyncProgress,
                metrics: metrics,
                logger: logger
            )
        }
        
        container.register(type: BlockValidator.self, isSingleton: true) { di in
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)
            let metrics = di.resolve(SDKMetrics.self)
            let logger = di.resolve(Logger.self)

            return BlockValidatorImpl(
                rustBackend: rustBackend,
                metrics: metrics,
                logger: logger
            )
        }

        container.register(type: BlockScanner.self, isSingleton: true) { di in
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)
            let transactionRepository = di.resolve(TransactionRepository.self)
            let metrics = di.resolve(SDKMetrics.self)
            let logger = di.resolve(Logger.self)
            let latestBlocksDataProvider = di.resolve(LatestBlocksDataProvider.self)

            let blockScannerConfig = BlockScannerConfig(
                networkType: config.network.networkType,
                scanningBatchSize: config.scanningBatchSize
            )

            return BlockScannerImpl(
                config: blockScannerConfig,
                rustBackend: rustBackend,
                transactionRepository: transactionRepository,
                metrics: metrics,
                logger: logger,
                latestBlocksDataProvider: latestBlocksDataProvider
            )
        }
        
        container.register(type: BlockEnhancer.self, isSingleton: true) { di in
            let blockDownloaderService = di.resolve(BlockDownloaderService.self)
            let internalSyncProgress = di.resolve(InternalSyncProgress.self)
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)
            let transactionRepository = di.resolve(TransactionRepository.self)
            let metrics = di.resolve(SDKMetrics.self)
            let logger = di.resolve(Logger.self)

            return BlockEnhancerImpl(
                blockDownloaderService: blockDownloaderService,
                internalSyncProgress: internalSyncProgress,
                rustBackend: rustBackend,
                transactionRepository: transactionRepository,
                metrics: metrics,
                logger: logger
            )
        }
        
        container.register(type: UTXOFetcher.self, isSingleton: true) { di in
            let blockDownloaderService = di.resolve(BlockDownloaderService.self)
            let utxoFetcherConfig = UTXOFetcherConfig(walletBirthdayProvider: config.walletBirthdayProvider)
            let internalSyncProgress = di.resolve(InternalSyncProgress.self)
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)
            let metrics = di.resolve(SDKMetrics.self)
            let logger = di.resolve(Logger.self)
            
            return UTXOFetcherImpl(
                accountRepository: accountRepository,
                blockDownloaderService: blockDownloaderService,
                config: utxoFetcherConfig,
                internalSyncProgress: internalSyncProgress,
                rustBackend: rustBackend,
                metrics: metrics,
                logger: logger
            )
        }
        
        container.register(type: SaplingParametersHandler.self, isSingleton: true) { di in
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)
            let logger = di.resolve(Logger.self)

            let saplingParametersHandlerConfig = SaplingParametersHandlerConfig(
                outputParamsURL: config.outputParamsURL,
                spendParamsURL: config.spendParamsURL,
                saplingParamsSourceURL: config.saplingParamsSourceURL
            )
            
            return SaplingParametersHandlerImpl(
                config: saplingParametersHandlerConfig,
                rustBackend: rustBackend,
                logger: logger
            )
        }
    }
}
