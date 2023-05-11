//
//  ComputeSyncRangesAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ComputeSyncRangesAction {
    init(container: DIContainer) { }
}

extension ComputeSyncRangesAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProgress) async -> Void) async throws -> ActionContext {
        // call internalSyncProgress and compute sync ranges and store them in context
        // if there is nothing sync just switch to finished state

        await context.update(state: .checksBeforeSync)
        return context
    }

    func stop() async { }
}
