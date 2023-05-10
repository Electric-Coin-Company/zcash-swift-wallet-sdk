//
//  ScandownloadedButUnscannedAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ScanDownloadedButUnscannedAction {
    init(container: DIContainer) { }
}

extension ScanDownloadedButUnscannedAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
//        if let range = ranges.downloadedButUnscannedRange {
//            logger.debug("Starting scan with downloaded but not scanned blocks with range: \(range.lowerBound)...\(range.upperBound)")
//            try await blockScanner.scanBlocks(at: range, totalProgressRange: totalProgressRange) { [weak self] lastScannedHeight in
//                let progress = BlockProgress(
//                    startHeight: totalProgressRange.lowerBound,
//                    targetHeight: totalProgressRange.upperBound,
//                    progressHeight: lastScannedHeight
//                )
//                await self?.notifyProgress(.syncing(progress))
//            }
//        }

        await context.update(state: .download)
        return context
    }

    func stop() async { }
}
