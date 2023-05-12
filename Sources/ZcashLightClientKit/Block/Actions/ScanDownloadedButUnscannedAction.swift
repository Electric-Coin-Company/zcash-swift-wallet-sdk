//
//  ScandownloadedButUnscannedAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ScanDownloadedButUnscannedAction {
    let logger: Logger
    let blockScanner: BlockScanner
    
    init(container: DIContainer) {
        logger = container.resolve(Logger.self)
        blockScanner = container.resolve(BlockScanner.self)
    }
}

extension ScanDownloadedButUnscannedAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        if let range = await context.syncRanges.downloadedButUnscannedRange {
            logger.debug("Starting scan with downloaded but not scanned blocks with range: \(range.lowerBound)...\(range.upperBound)")
            let totalProgressRange = await context.totalProgressRange
            try await blockScanner.scanBlocks(at: range, totalProgressRange: totalProgressRange) { lastScannedHeight in
                let progress = BlockProgress(
                    startHeight: totalProgressRange.lowerBound,
                    targetHeight: totalProgressRange.upperBound,
                    progressHeight: lastScannedHeight
                )
                await didUpdate(.progressUpdated(.syncing(progress)))
            }
        }
        await context.update(state: .download)
        return context
    }

    func stop() async { }
}
