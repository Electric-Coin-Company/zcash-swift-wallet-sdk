//
//  ComputeSyncControlDataAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class ComputeSyncControlDataAction {
    let configProvider: CompactBlockProcessor.ConfigProvider
    let downloaderService: BlockDownloaderService
    let latestBlocksDataProvider: LatestBlocksDataProvider
    let logger: Logger
    
    init(container: DIContainer, configProvider: CompactBlockProcessor.ConfigProvider) {
        self.configProvider = configProvider
        downloaderService = container.resolve(BlockDownloaderService.self)
        latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        logger = container.resolve(Logger.self)
    }
}

extension ComputeSyncControlDataAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        let config = await configProvider.config

        await latestBlocksDataProvider.updateScannedData()
        await latestBlocksDataProvider.updateBlockData()
        await latestBlocksDataProvider.updateUnenhancedData()

        // Here we know:
        // - latest scanned height from the DB, if none the wallet's birthday is automatically used
        // - first unenhanced height from the DB, could be nil = up to latestScannedHeight nothing to enhance
        // - latest downloaded height reported by downloaderService
        // - latest block height on the blockchain
        // - wallet birthday for the initial scan

        let latestBlockHeight = await latestBlocksDataProvider.latestBlockHeight
        let latestScannedHeightDB = await latestBlocksDataProvider.latestScannedHeight
        let latestScannedHeight = latestScannedHeightDB < config.walletBirthday ? config.walletBirthday : latestScannedHeightDB
        let firstUnenhancedHeight = await latestBlocksDataProvider.firstUnenhancedHeight
        let enhanceStart: BlockHeight
        if let firstUnenhancedHeight {
            enhanceStart = min(firstUnenhancedHeight, latestScannedHeight)
        } else {
            enhanceStart = latestScannedHeight
        }
        
        logger.debug("""
            Init numbers:
            latestBlockHeight [BC]:         \(latestBlockHeight)
            latestScannedHeight [DB]:       \(latestScannedHeight)
            firstUnenhancedHeight [DB]:     \(firstUnenhancedHeight ?? -1)
            enhanceStart:                   \(enhanceStart)
            walletBirthday:                 \(config.walletBirthday)
            """)

        let syncControlData = SyncControlData(
            latestBlockHeight: latestBlockHeight,
            latestScannedHeight: latestScannedHeight,
            firstUnenhancedHeight: enhanceStart
        )
        
        await context.update(lastDownloadedHeight: latestScannedHeight)
        await context.update(syncControlData: syncControlData)
        await context.update(totalProgressRange: latestScannedHeight...latestBlockHeight)

        // if there is nothing sync just switch to finished state
        if latestBlockHeight < latestScannedHeight || latestBlockHeight == latestScannedHeight {
            await context.update(state: .finished)
        } else {
            await context.update(state: .fetchUTXO)
        }
        
        return context
    }

    func stop() async { }
}
