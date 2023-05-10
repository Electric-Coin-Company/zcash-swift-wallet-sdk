//
//  DownloadAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class DownloadAction {
    init(container: DIContainer) { }
}

extension DownloadAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // Use `BlockDownloader` to set download limit to latestScannedHeight + (2*batchSize) (after parallel is merged).
        // And start download.
        // Compute batch sync range (range used by one loop in `downloadAndScanBlocks` method) and wait until blocks in this range are downloaded.

//        do {
//            await blockDownloader.setDownloadLimit(processingRange.upperBound + (2 * batchSize))
//            await blockDownloader.startDownload(maxBlockBufferSize: config.downloadBufferSize)
//
//            try await blockDownloader.waitUntilRequestedBlocksAreDownloaded(in: processingRange)
//        } catch {
//            await ifTaskIsNotCanceledClearCompactBlockCache(lastScannedHeight: lastScannedHeight)
//            throw error
//        }

        await context.update(state: .validate)
        return context
    }

    func stop() {

    }
}
