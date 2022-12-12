//
//  FigureNextBatch.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 6/17/21.
//

import Foundation

extension CompactBlockProcessor {
    enum NextState: Equatable {
        case finishProcessing(height: BlockHeight)
        case processNewBlocks(ranges: SyncRanges)
        case wait(latestHeight: BlockHeight, latestDownloadHeight: BlockHeight)
    }

    @discardableResult
    func figureNextBatch(
        downloader: CompactBlockDownloading
    ) async throws -> NextState {
        try Task.checkCancellation()
        
        do {
            return try await CompactBlockProcessor.NextStateHelper.nextStateAsync(
                service: service,
                downloader: downloader,
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
