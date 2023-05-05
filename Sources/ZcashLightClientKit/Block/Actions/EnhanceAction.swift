//
//  EnhanceAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class EnhanceAction {
    init() { }
}

extension EnhanceAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // Use `BlockEnhancer` to enhance blocks.

        await context.update(state: .fetchUTXO)
        return context
    }
}
