//
//  EnhanceAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class EnhanceAction {
    let blockEnhancer: BlockEnhancer
    let config: CompactBlockProcessorNG.Configuration
    let internalSyncProgress: InternalSyncProgress
    let logger: Logger
    let transactionRepository: TransactionRepository
    init(container: DIContainer, config: CompactBlockProcessorNG.Configuration) {
        blockEnhancer = container.resolve(BlockEnhancer.self)
        self.config = config
        internalSyncProgress = container.resolve(InternalSyncProgress.self)
        logger = container.resolve(Logger.self)
        transactionRepository = container.resolve(TransactionRepository.self)
    }

    func decideWhatToDoNext(context: ActionContext, lastScannedHeight: BlockHeight) async -> ActionContext {
        guard let downloadAndScanRange = await context.syncRanges.downloadAndScanRange else {
            await context.update(state: .clearCache)
            return context
        }

        if lastScannedHeight >= downloadAndScanRange.upperBound {
            await context.update(state: .clearCache)
        } else {
            await context.update(state: .download)
        }

        return context
    }
}

extension EnhanceAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        // Use `BlockEnhancer` to enhance blocks.
        // This action is executed on each downloaded and scanned batch (typically each 100 blocks). But we want to run enhancement each 1000 blocks.
        // This action can use `InternalSyncProgress` and last scanned height to compute when it should do work.

        // if latestScannedHeight == context.scanRanges.downloadAndScanRange?.upperBound then set state `enhance`. Everything is scanned.
        // If latestScannedHeight < context.scanRanges.downloadAndScanRange?.upperBound thne set state to `download` because there are blocks to
        // download and scan.

        let lastScannedHeight = try await transactionRepository.lastScannedHeight()

        guard let range = await context.syncRanges.enhanceRange else {
            return await decideWhatToDoNext(context: context, lastScannedHeight: lastScannedHeight)
        }

        let lastEnhancedHeight = await internalSyncProgress.load(.latestEnhancedHeight)
        let enhanceRangeStart = max(range.lowerBound, lastEnhancedHeight)
        let enhanceRangeEnd = min(range.upperBound, lastScannedHeight)

        if enhanceRangeStart <= enhanceRangeEnd && lastEnhancedHeight - lastScannedHeight >= config.enhanceBatchSize {
            let enhanceRange = enhanceRangeStart...enhanceRangeEnd
            let transactions = try await blockEnhancer.enhance(at: enhanceRange) { progress in
                await didUpdate(.progressUpdated(.enhance(progress)))
            }
            await didUpdate(.foundTransactions(transactions, enhanceRange))
        }

        return await decideWhatToDoNext(context: context, lastScannedHeight: lastScannedHeight)
    }

    func stop() async { }
}
