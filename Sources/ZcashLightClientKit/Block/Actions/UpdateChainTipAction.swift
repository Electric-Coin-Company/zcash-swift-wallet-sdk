//
//  UpdateChainTipAction.swift
//  
//
//  Created by Lukáš Korba on 01.08.2023.
//

import Foundation

final class UpdateChainTipAction {
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        logger = container.resolve(Logger.self)
    }
}

extension UpdateChainTipAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        let latestBlockHeight = try await service.latestBlockHeight()
        
        logger.info("Latest block height is \(latestBlockHeight)")
        try await rustBackend.updateChainTip(height: Int32(latestBlockHeight))
        
        await context.update(state: .validatePreviousWalletSession)

        return context
    }

    func stop() async { }
}
