//
//  EnhanceAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class EnhanceAction {
    init(container: DIContainer) { }
}

extension EnhanceAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // Use `BlockEnhancer` to enhance blocks.
        // This action is executed on each downloaded and scanned batch (typically each 100 blocks). But we want to run enhancement each 1000 blocks.
        // This action can use `InternalSyncProgress` and last scanned height to compute when it should do work.

        // if latestScannedHeight == context.scanRanges.downloadAndScanRange?.upperBound then set state `enhance`. Everything is scanned.
        // If latestScannedHeight < context.scanRanges.downloadAndScanRange?.upperBound thne set state to `download` because there are blocks to
        // download and scan.

        await context.update(state: .clearCache)
        return context
    }

    func stop() async { }
}
