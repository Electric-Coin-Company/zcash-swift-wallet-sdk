//
//  Dependencies.swift
//  
//
//  Created by Michal Fousek on 01.05.2023.
//

import Foundation

enum Dependencies {
    // swiftlint:disable:next function_parameter_count
    static func setup(
        in container: DIContainer,
        urls: Initializer.URLs,
        alias: ZcashSynchronizerAlias,
        networkType: NetworkType,
        endpoint: LightWalletEndpoint,
        logLevel: OSLogger.LogLevel
    ) {
        container.register(type: OSLogger.self, isSingleton: true) { _ in
            OSLogger(logLevel: logLevel, alias: alias)
        }

        container.register(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in
            return ZcashRustBackend(
                dbData: urls.dataDbURL,
                fsBlockDbRoot: urls.fsBlockDbRoot,
                spendParamsPath: urls.spendParamsURL,
                outputParamsPath: urls.spendParamsURL,
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
            let logger = di.resolve(OSLogger.self)
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
    }
}
