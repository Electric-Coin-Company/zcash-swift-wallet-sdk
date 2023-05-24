//
//  EnhanceAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class EnhanceAction {
    let blockEnhancer: BlockEnhancer
    let configProvider: CompactBlockProcessor.ConfigProvider
    let internalSyncProgress: InternalSyncProgress
    let logger: Logger
    let transactionRepository: TransactionRepository
    init(container: DIContainer, configProvider: CompactBlockProcessor.ConfigProvider) {
        blockEnhancer = container.resolve(BlockEnhancer.self)
        self.configProvider = configProvider
        internalSyncProgress = container.resolve(InternalSyncProgress.self)
        logger = container.resolve(Logger.self)
        transactionRepository = container.resolve(TransactionRepository.self)
    }

    func decideWhatToDoNext(context: ActionContext, lastScannedHeight: BlockHeight) async -> ActionContext {
        guard let scanRange = await context.syncRanges.scanRange else {
            await context.update(state: .clearCache)
            return context
        }

        if lastScannedHeight >= scanRange.upperBound {
            await context.update(state: .clearCache)
        } else {
            await context.update(state: .download)
        }

        return context
    }
}

extension EnhanceAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        // Use `BlockEnhancer` to enhance blocks.
        // This action is executed on each downloaded and scanned batch (typically each 100 blocks). But we want to run enhancement each 1000 blocks.
        // This action can use `InternalSyncProgress` and last scanned height to compute when it should do work.

        // if latestScannedHeight == context.scanRanges.downloadAndScanRange?.upperBound then set state `clearCache`. Everything is scanned.
        // If latestScannedHeight < context.scanRanges.downloadAndScanRange?.upperBound then set state to `download` because there are blocks to
        // download and scan.

        let config = await configProvider.config
        let lastScannedHeight = try await transactionRepository.lastScannedHeight()

        guard let range = await context.syncRanges.enhanceRange else {
            return await decideWhatToDoNext(context: context, lastScannedHeight: lastScannedHeight)
        }

        let lastEnhancedHeight = try await internalSyncProgress.load(.latestEnhancedHeight)
        let enhanceRangeStart = max(range.lowerBound, lastEnhancedHeight)
        let enhanceRangeEnd = min(range.upperBound, lastScannedHeight)

        // This may happen:
        // For example whole enhance range is 0...2100 Without this force enhance is done for ranges: 0...1000, 1001...2000. And that's it.
        // Last 100 blocks isn't enhanced.
        //
        // This force makes sure that all the blocks are enhanced even when last enhance happened < 1000 blocks ago.
        let forceEnhance = enhanceRangeEnd == range.upperBound && enhanceRangeEnd - enhanceRangeStart <= config.enhanceBatchSize

        if forceEnhance || (enhanceRangeStart <= enhanceRangeEnd && lastScannedHeight - lastEnhancedHeight >= config.enhanceBatchSize) {
            let enhanceRange = enhanceRangeStart...enhanceRangeEnd
            let transactions = try await blockEnhancer.enhance(
                at: enhanceRange,
                didEnhance: { progress in
                    if let foundTx = progress.lastFoundTransaction, progress.newlyMined {
                        await didUpdate(.minedTransaction(foundTx))
                    }
                }
            )

            if let transactions {
                await didUpdate(.foundTransactions(transactions, enhanceRange))
            }
        }

        return await decideWhatToDoNext(context: context, lastScannedHeight: lastScannedHeight)
    }

    func stop() async { }
}
