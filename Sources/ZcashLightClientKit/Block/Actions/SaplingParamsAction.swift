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
        // TODO: [#1512] This is hardcoded Zip32AccountIndex for index 0, must be updated
        // https://github.com/Electric-Coin-Company/zcash-swift-wallet-sdk/issues/1512
        try await saplingParametersHandler.handleIfNeeded(accountIndex: Zip32AccountIndex(0))
        
        await context.update(state: .updateSubtreeRoots)
        
        return context
    }

    func stop() async { }
}
