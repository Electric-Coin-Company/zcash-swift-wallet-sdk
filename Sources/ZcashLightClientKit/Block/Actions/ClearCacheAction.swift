//
//  ClearCacheAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class ClearCacheAction {
    let storage: CompactBlockRepository

    init(container: DIContainer) {
        storage = container.resolve(CompactBlockRepository.self)
    }
}

extension ClearCacheAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        try await storage.clear()
        if await context.prevState == .idle {
            await context.update(state: .migrateLegacyCacheDB)
        } else {
            if context.preferredSyncAlgorithm == .linear {
                await context.update(state: .finished)
            } else {
                if let supportedSyncAlgorithm = await context.supportedSyncAlgorithm {
                    if supportedSyncAlgorithm == .linear {
                        await context.update(state: .finished)
                    } else {
                        await context.update(state: .processSuggestedScanRanges)
                    }
                } else {
                    throw ZcashError.compactBlockProcessorSupportedSyncAlgorithm
                }
            }
        }
        return context
    }

    func stop() async { }
}
