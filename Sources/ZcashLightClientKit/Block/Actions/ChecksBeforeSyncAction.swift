//
//  ChecksBeforeSyncAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ChecksBeforeSyncAction {
    init(container: DIContainer) { }
}

extension ChecksBeforeSyncAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        // clear any present cached state if needed.
        // this checks if there was a sync in progress that was
        // interrupted abruptly and cache was not able to be cleared
        // properly and internal state set to the appropriate value
//        if let newLatestDownloadedHeight = ranges.shouldClearBlockCacheAndUpdateInternalState() {
//            try await storage.clear()
//            await internalSyncProgress.set(newLatestDownloadedHeight, .latestDownloadedBlockHeight)
//        } else {
//            try await storage.create()
//        }

        await context.update(state: .fetchUTXO)
        return context
    }

    func stop() async { }
}
