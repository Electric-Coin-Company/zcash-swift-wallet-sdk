//
//  ClearCacheForLastScannedBatch.swift
//  
//
//  Created by Michal Fousek on 08.05.2023.
//

import Foundation

final class ClearAlreadyScannedBlocksAction {
    let storage: CompactBlockRepository
    let transactionRepository: TransactionRepository
    
    init(container: DIContainer) {
        storage = container.resolve(CompactBlockRepository.self)
        transactionRepository = container.resolve(TransactionRepository.self)
    }
    
    func decideWhatToDoNext(context: ActionContext, lastScannedHeight: BlockHeight) async -> ActionContext {
        guard await context.syncControlData.latestScannedHeight != nil else {
            await context.update(state: .clearCache)
            return context
        }

        let latestBlockHeight = await context.syncControlData.latestBlockHeight
        if lastScannedHeight >= latestBlockHeight {
            await context.update(state: .clearCache)
        } else {
            await context.update(state: .txResubmission)
        }

        return context
    }
}

extension ClearAlreadyScannedBlocksAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let lastScannedHeight = await context.lastScannedHeight else {
            throw ZcashError.compactBlockProcessorLastScannedHeight
        }
        
        try await storage.clear(upTo: lastScannedHeight)

        return await decideWhatToDoNext(context: context, lastScannedHeight: lastScannedHeight)
    }

    func stop() async { }
}
