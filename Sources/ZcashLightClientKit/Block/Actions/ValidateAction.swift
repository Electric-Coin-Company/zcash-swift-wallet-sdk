//
//  ValidateAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ValidateAction {
    let validator: BlockValidator
    init(container: DIContainer) {
        validator = container.resolve(BlockValidator.self)
    }
}

extension ValidateAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProgress) async -> Void) async throws -> ActionContext {
        try await validator.validate()
        await context.update(state: .scan)
        return context
    }

    func stop() async { }
}
