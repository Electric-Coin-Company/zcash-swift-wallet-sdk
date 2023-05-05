//
//  ValidateAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ValidateAction {
    init() { }
}

extension ValidateAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {

        // Wait until all blocks in range latestScannedHeight...latestScannedHeight+batchSize are downloaded and then run validation.

        await context.update(state: .scan)
        return context
    }
}
