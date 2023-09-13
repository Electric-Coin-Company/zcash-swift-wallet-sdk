//
//  RewindAction.swift
//  
//
//  Created by Lukáš Korba on 09.08.2023.
//

import Foundation

final class RewindAction {
    let downloader: BlockDownloader
    let rustBackend: ZcashRustBackendWelding
    let downloaderService: BlockDownloaderService
    let logger: Logger

    init(container: DIContainer) {
        downloader = container.resolve(BlockDownloader.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        downloaderService = container.resolve(BlockDownloaderService.self)
        logger = container.resolve(Logger.self)
    }
    
    private func update(context: ActionContext) async -> ActionContext {
        await context.update(state: .processSuggestedScanRanges)
        return context
    }
}

extension RewindAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let rewindHeight = await context.requestedRewindHeight else {
            return await update(context: context)
        }
        
        logger.debug("Executing rewind.")
        await downloader.rewind(latestDownloadedBlockHeight: rewindHeight)
        try await rustBackend.rewindToHeight(height: Int32(rewindHeight))
        
        // clear cache
        try await downloaderService.rewind(to: rewindHeight)
        
        return await update(context: context)
    }

    func stop() async { }
}
