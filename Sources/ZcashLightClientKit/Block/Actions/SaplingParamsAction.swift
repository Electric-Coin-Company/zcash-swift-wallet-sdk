//
//  SaplingParamsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class SaplingParamsAction {
    init() { }
}

extension SaplingParamsAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {

        // Download files with sapling params.

        await context.update(state: .clearCache)
        return context
    }
}
