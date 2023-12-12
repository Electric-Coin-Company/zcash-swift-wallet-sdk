//
//  UpdateChainTipAction.swift
//  
//
//  Created by Lukáš Korba on 01.08.2023.
//

import Foundation

final class UpdateChainTipAction {
    let rustBackend: ZcashRustBackendWelding
    let downloader: BlockDownloader
    let service: LightWalletService
    let latestBlocksDataProvider: LatestBlocksDataProvider
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        downloader = container.resolve(BlockDownloader.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        logger = container.resolve(Logger.self)
    }
    
    func updateChainTip(_ context: ActionContext, time: TimeInterval) async throws {
        let latestBlockHeight = try await service.latestBlockHeight()
        
        logger.debug("Latest block height is \(latestBlockHeight)")
        try await rustBackend.updateChainTip(height: Int32(latestBlockHeight))
        await context.update(lastChainTipUpdateTime: time)
        await latestBlocksDataProvider.update(latestBlockHeight)
    }
}

extension UpdateChainTipAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        let lastChainTipUpdateTime = await context.lastChainTipUpdateTime
        let now = Date().timeIntervalSince1970

        // Update chain tip can be called from different contexts
        if await context.prevState == .updateSubtreeRoots || now - lastChainTipUpdateTime > 600 {
            await downloader.stopDownload()
            try await updateChainTip(context, time: now)
            await context.update(state: .clearCache)
        } else if await context.prevState == .enhance {
            await context.update(state: .download)
        }
        
        return context
    }

    func stop() async { }
}
