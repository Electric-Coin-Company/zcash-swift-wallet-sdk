//
//  ScanAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ScanAction {
    let config: CompactBlockProcessor.Configuration
    let blockScanner: BlockScanner
    let logger: Logger
    let transactionRepository: TransactionRepository

    init(container: DIContainer, config: CompactBlockProcessor.Configuration) {
        self.config = config
        blockScanner = container.resolve(BlockScanner.self)
        transactionRepository = container.resolve(TransactionRepository.self)
        logger = container.resolve(Logger.self)
    }

    private func update(context: ActionContext) async -> ActionContext {
        await context.update(state: .clearAlreadyScannedBlocks)
        return context
    }
}

extension ScanAction: Action {
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let scanRange = await context.syncRanges.downloadAndScanRange else {
            return await update(context: context)
        }
        
        let lastScannedHeight = try await transactionRepository.lastScannedHeight()
        // This action is executed for each batch (batch size is 100 blocks by default) until all the blocks in whole `scanRange` are scanned.
        // So the right range for this batch must be computed.
        let batchRangeStart = max(scanRange.lowerBound, lastScannedHeight)
        let batchRangeEnd = min(scanRange.upperBound, batchRangeStart + config.batchSize)

        guard batchRangeStart <= batchRangeEnd else {
            return await update(context: context)
        }

        let batchRange = batchRangeStart...batchRangeStart + config.batchSize
        
        logger.debug("Starting scan blocks with range: \(batchRange.lowerBound)...\(batchRange.upperBound)")
        let totalProgressRange = await context.totalProgressRange
        try await blockScanner.scanBlocks(at: batchRange, totalProgressRange: totalProgressRange) { [weak self] lastScannedHeight in
            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: lastScannedHeight
            )
            self?.logger.debug("progress: \(progress)")
            await didUpdate(.progressUpdated(.syncing(progress)))
        }

        return await update(context: context)
    }

    func stop() async { }
}
