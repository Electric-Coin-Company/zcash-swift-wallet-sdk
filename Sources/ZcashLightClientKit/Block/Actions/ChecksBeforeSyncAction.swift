//
//  ChecksBeforeSyncAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ChecksBeforeSyncAction {
    let internalSyncProgress: InternalSyncProgress
    let storage: CompactBlockRepository
    init(container: DIContainer) {
        internalSyncProgress = container.resolve(InternalSyncProgress.self)
        storage = container.resolve(CompactBlockRepository.self)
    }

    /// Tells whether the state represented by these sync ranges evidence some sort of
    /// outdated state on the cache or the internal state of the compact block processor.
    ///
    /// - Note: this can mean that the processor has synced over the height that the internal
    /// state knows of because the sync process was interrupted before it could reflect
    /// it in the internal state storage. This could happen because of many factors, the
    /// most feasible being OS shutting down a background process or the user abruptly
    /// exiting the app.
    /// - Returns: an ``Optional<BlockHeight>`` where Some represents what's the
    /// new state the internal state should reflect and indicating that the cache should be cleared
    /// as well. c`None` means that no action is required.
    func shouldClearBlockCacheAndUpdateInternalState(syncRange: SyncRanges) -> BlockHeight? {
        guard syncRange.downloadedButUnscannedRange != nil else {
            return nil
        }

        guard
            let latestScannedHeight = syncRange.latestScannedHeight,
            let latestDownloadedHeight = syncRange.latestDownloadedBlockHeight,
            latestScannedHeight > latestDownloadedHeight
        else { return nil }

        return latestScannedHeight
    }
}

extension ChecksBeforeSyncAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        // clear any present cached state if needed.
        // this checks if there was a sync in progress that was
        // interrupted abruptly and cache was not able to be cleared
        // properly and internal state set to the appropriate value
        if let newLatestDownloadedHeight = shouldClearBlockCacheAndUpdateInternalState(syncRange: await context.syncRanges) {
            try await storage.clear()
            try await internalSyncProgress.set(newLatestDownloadedHeight, .latestDownloadedBlockHeight)
        } else {
            try await storage.create()
        }

        await context.update(state: .fetchUTXO)
        return context
    }

    func stop() async { }
}
