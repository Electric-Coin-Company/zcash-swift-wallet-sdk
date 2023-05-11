//
//  SaplingParamsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class SaplingParamsAction {
    init(container: DIContainer) { }
}

extension SaplingParamsAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        // Download files with sapling params.

        await context.update(state: .scanDownloaded)
        return context
    }

    func stop() async { }
}
