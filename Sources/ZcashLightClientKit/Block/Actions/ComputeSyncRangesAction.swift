//
//  ComputeSyncRangesAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ComputeSyncRangesAction {
    init() { }
}

extension ComputeSyncRangesAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // call internalSyncProgress and compute sync ranges and store them in context
        await context.update(state: .checksBeforeSync)
        return context
    }
}
