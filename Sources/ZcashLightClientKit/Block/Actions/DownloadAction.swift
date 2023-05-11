//
//  DownloadAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class DownloadAction {
    let config: CompactBlockProcessorNG.Configuration
    let downloader: BlockDownloader
    let transactionRepository: TransactionRepository
    init(container: DIContainer, config: CompactBlockProcessorNG.Configuration) {
        self.config = config
        downloader = container.resolve(BlockDownloader.self)
        transactionRepository = container.resolve(TransactionRepository.self)
    }

    private func update(context: ActionContext) async -> ActionContext {
        await context.update(state: .validate)
        return context
    }
}

extension DownloadAction: Action {
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        guard let downloadRange = await context.syncRanges.downloadAndScanRange else {
            return await update(context: context)
        }

        let lastScannedHeight = try await transactionRepository.lastScannedHeight()
        let downloadLimit = lastScannedHeight + (2 * config.batchSize)
        let batchRange = lastScannedHeight...lastScannedHeight + config.batchSize

        try await downloader.setSyncRange(downloadRange)
        await downloader.setDownloadLimit(downloadLimit)

        try await downloader.waitUntilRequestedBlocksAreDownloaded(in: batchRange)

        await context.update(state: .validate)
        return context
    }

    func stop() async {
        await downloader.stopDownload()
    }
}
