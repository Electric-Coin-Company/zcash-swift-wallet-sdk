//
//  ClearCacheForLastScannedBatch.swift
//  
//
//  Created by Michal Fousek on 08.05.2023.
//

import Foundation

class ClearAlreadyScannedBlocksAction {
    init() { }
}

extension ClearAlreadyScannedBlocksAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // clear storage but delete only blocks that were already scanned, when doing parallel download all blocks can't be deleted

        // if latestScannedHeight == context.scanRanges.downloadAndScanRange?.upperBound then set state `enhance`. Everything is scanned.
        // If latestScannedHeight < context.scanRanges.downloadAndScanRange?.upperBound thne set state to `download` because there are blocks to
        // download and scan.

        await context.update(state: .enhance)
        return context
    }
}
