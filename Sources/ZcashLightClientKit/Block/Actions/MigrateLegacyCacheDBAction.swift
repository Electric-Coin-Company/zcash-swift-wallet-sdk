//
//  MigrateLegacyCacheDB.swift
//  
//
//  Created by Michal Fousek on 10.05.2023.
//

import Foundation

final class MigrateLegacyCacheDBAction {
    private let config: CompactBlockProcessor.Configuration
    private let internalSyncProgress: InternalSyncProgress
    private let storage: CompactBlockRepository
    private let transactionRepository: TransactionRepository
    private let fileManager: ZcashFileManager

    init(container: DIContainer, config: CompactBlockProcessor.Configuration) {
        self.config = config
        internalSyncProgress = container.resolve(InternalSyncProgress.self)
        storage = container.resolve(CompactBlockRepository.self)
        transactionRepository = container.resolve(TransactionRepository.self)
        fileManager = container.resolve(ZcashFileManager.self)
    }

    private func updateState(_ context: ActionContext) async -> ActionContext {
        await context.update(state: .validateServer)
        return context
    }
}

extension MigrateLegacyCacheDBAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let legacyCacheDbURL = config.cacheDbURL else {
            return await updateState(context)
        }

        guard legacyCacheDbURL != config.fsBlockCacheRoot else {
            throw ZcashError.compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL
        }

        // Instance with alias `default` is same as instance before the Alias was introduced. So it makes sense that only this instance handles
        // legacy cache DB. Any instance with different than `default` alias was created after the Alias was introduced and at this point legacy
        // cache DB is't anymore. So there is nothing to migrate for instances with not default Alias.
        guard config.alias == .default else {
            return await updateState(context)
        }

        // if the URL provided is not readable, it means that the client has a reference
        // to the cacheDb file but it has been deleted in a prior sync cycle. there's
        // nothing to do here.
        guard fileManager.isReadableFile(atPath: legacyCacheDbURL.path) else {
            return await updateState(context)
        }

        do {
            // if there's a readable file at the provided URL, delete it.
            try fileManager.removeItem(at: legacyCacheDbURL)
        } catch {
            throw ZcashError.compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb(error)
        }

        // create the storage
        try await self.storage.create()

        // The database has been deleted, so we have adjust the internal state of the
        // `CompactBlockProcessor` so that it doesn't rely on download heights set
        // by a previous processing cycle.
        let lastScannedHeight = try await transactionRepository.lastScannedHeight()

        await internalSyncProgress.set(lastScannedHeight, .latestDownloadedBlockHeight)

        return await updateState(context)
    }

    func stop() { }
}
