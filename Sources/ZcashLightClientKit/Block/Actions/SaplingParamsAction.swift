//
//  SaplingParamsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class SaplingParamsAction {
    let saplingParametersHandler: SaplingParametersHandler
    init(container: DIContainer) {
        saplingParametersHandler = container.resolve(SaplingParametersHandler.self)
    }
}

extension SaplingParamsAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        try await saplingParametersHandler.handleIfNeeded()
        await context.update(state: .scanDownloaded)
        return context
    }

    func stop() async { }
}
