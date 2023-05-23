//
//  ComputeSyncRangesAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class ComputeSyncRangesAction {
    let config: CompactBlockProcessor.Configuration
    let downloaderService: BlockDownloaderService
    let internalSyncProgress: InternalSyncProgress
    let latestBlocksDataProvider: LatestBlocksDataProvider
    let logger: Logger
    
    init(container: DIContainer, config: CompactBlockProcessor.Configuration) {
        self.config = config
        downloaderService = container.resolve(BlockDownloaderService.self)
        internalSyncProgress = container.resolve(InternalSyncProgress.self)
        latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        logger = container.resolve(Logger.self)
    }

    /// It may happen that sync process start with syncing blocks that were downloaded but not synced in previous run of the sync process. This
    /// methods analyses what must be done and computes range that should be used to compute reported progress.
    func computeTotalProgressRange(from syncRanges: SyncRanges) -> CompactBlockRange {
        guard syncRanges.downloadRange != nil || syncRanges.scanRange != nil else {
            // In this case we are sure that no downloading or scanning happens so this returned range won't be even used. And it's easier to return
            // this "fake" range than to handle nil.
            return 0...0
        }

        // Thanks to guard above we can be sure that one of these two ranges is not nil.
        let lowerBound = syncRanges.scanRange?.lowerBound ?? syncRanges.downloadRange?.lowerBound ?? 0
        let upperBound = syncRanges.scanRange?.upperBound ?? syncRanges.downloadRange?.upperBound ?? 0

        return lowerBound...upperBound
    }
}

extension ComputeSyncRangesAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        // call internalSyncProgress and compute sync ranges and store them in context
        // if there is nothing sync just switch to finished state

        let latestDownloadHeight = try await downloaderService.lastDownloadedBlockHeight()

        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadHeight)

        await latestBlocksDataProvider.updateScannedData()
        await latestBlocksDataProvider.updateBlockData()

        let nextState = await internalSyncProgress.computeNextState(
            latestBlockHeight: latestBlocksDataProvider.latestBlockHeight,
            latestScannedHeight: latestBlocksDataProvider.latestScannedHeight,
            walletBirthday: config.walletBirthday
        )

        switch nextState {
        case .finishProcessing:
            await context.update(state: .finished)
        case .processNewBlocks(let ranges):
            let totalProgressRange = computeTotalProgressRange(from: ranges)
            await context.update(totalProgressRange: totalProgressRange)
            await context.update(syncRanges: ranges)
            await context.update(state: .checksBeforeSync)

            logger.debug("""
            Syncing with ranges:
            download:                   \(ranges.downloadRange?.lowerBound ?? -1)...\(ranges.downloadRange?.upperBound ?? -1)
            scan:                       \(ranges.scanRange?.lowerBound ?? -1)...\(ranges.scanRange?.upperBound ?? -1)
            enhance range:              \(ranges.enhanceRange?.lowerBound ?? -1)...\(ranges.enhanceRange?.upperBound ?? -1)
            fetchUTXO range:            \(ranges.fetchUTXORange?.lowerBound ?? -1)...\(ranges.fetchUTXORange?.upperBound ?? -1)
            total progress range:       \(totalProgressRange.lowerBound)...\(totalProgressRange.upperBound)
            """)

        case let .wait(latestHeight, latestDownloadHeight):
            // Lightwalletd might be syncing
            logger.info(
                "Lightwalletd might be syncing: latest downloaded block height is: \(latestDownloadHeight) " +
                "while latest blockheight is reported at: \(latestHeight)"
            )
            await context.update(state: .finished)
        }

        return context
    }

    func stop() async { }
}
