//
//  SaplingParamsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class SaplingParamsAction {
    let saplingParametersHandler: SaplingParametersHandler
    let logger: Logger

    init(container: DIContainer) {
        saplingParametersHandler = container.resolve(SaplingParametersHandler.self)
        logger = container.resolve(Logger.self)
    }
}

extension SaplingParamsAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        logger.debug("Fetching sapling parameters")
        // TODO: This is hardcoded Zip32Account for index 0, must be updated
        try await saplingParametersHandler.handleIfNeeded(account: Zip32Account(0))
        
        await context.update(state: .updateSubtreeRoots)
        
        return context
    }

    func stop() async { }
}
