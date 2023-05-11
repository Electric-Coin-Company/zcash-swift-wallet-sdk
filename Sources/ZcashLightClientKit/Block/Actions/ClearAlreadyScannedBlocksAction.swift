//
//  ClearCacheForLastScannedBatch.swift
//  
//
//  Created by Michal Fousek on 08.05.2023.
//

import Foundation

class ClearAlreadyScannedBlocksAction {
    init(container: DIContainer) { }
}

extension ClearAlreadyScannedBlocksAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        // clear storage but delete only blocks that were already scanned, when doing parallel download all blocks can't be deleted

        await context.update(state: .enhance)
        return context
    }

    func stop() async { }
}
