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
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        try await validator.validate()
        await context.update(state: .scan)
        return context
    }

    func stop() async { }
}
