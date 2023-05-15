//
//  DownloadAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class DownloadAction {
    let config: CompactBlockProcessor.Configuration
    let downloader: BlockDownloader
    let transactionRepository: TransactionRepository
    let logger: Logger

    init(container: DIContainer, config: CompactBlockProcessor.Configuration) {
        self.config = config
        downloader = container.resolve(BlockDownloader.self)
        transactionRepository = container.resolve(TransactionRepository.self)
        logger = container.resolve(Logger.self)
    }

    private func update(context: ActionContext) async -> ActionContext {
        await context.update(state: .validate)
        return context
    }
}

extension DownloadAction: Action {
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let downloadRange = await context.syncRanges.downloadAndScanRange else {
            return await update(context: context)
        }

        let lastScannedHeight = try await transactionRepository.lastScannedHeight()
        // This action is executed for each batch (batch size is 100 blocks by default) until all the blocks in whole `downloadRange` are downloaded.
        // So the right range for this batch must be computed.
        let batchRangeStart = max(downloadRange.lowerBound, lastScannedHeight)
        let batchRangeEnd = min(downloadRange.upperBound, batchRangeStart + config.batchSize)

        guard batchRangeStart <= batchRangeEnd else {
            return await update(context: context)
        }

        let batchRange = batchRangeStart...batchRangeEnd
        let downloadLimit = batchRange.upperBound + (2 * config.batchSize)

        logger.debug("Starting download with range: \(batchRange.lowerBound)...\(batchRange.upperBound)")
        try await downloader.setSyncRange(downloadRange, batchSize: config.batchSize)
        await downloader.setDownloadLimit(downloadLimit)
        await downloader.startDownload(maxBlockBufferSize: config.downloadBufferSize)

        try await downloader.waitUntilRequestedBlocksAreDownloaded(in: batchRange)

        return await update(context: context)
    }

    func stop() async {
        await downloader.stopDownload()
    }
}
