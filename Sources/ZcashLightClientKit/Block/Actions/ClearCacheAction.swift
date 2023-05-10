//
//  ClearCacheAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ClearCacheAction {
    init(container: DIContainer) { }
}

extension ClearCacheAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // clear storage
        await context.update(state: .finished)
        return context
    }

    func stop() {

    }
}
