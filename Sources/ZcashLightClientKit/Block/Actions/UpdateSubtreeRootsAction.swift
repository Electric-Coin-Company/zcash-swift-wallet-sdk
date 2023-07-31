//
//  UpdateSubtreeRootsAction.swift
//  
//
//  Created by Lukas Korba on 01.08.2023.
//

import Foundation

final class UpdateSubtreeRootsAction {
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        logger = container.resolve(Logger.self)
    }
}

extension UpdateSubtreeRootsAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        var request = GetSubtreeRootsArg()
        request.shieldedProtocol = .sapling
        request.maxEntries = 65536
        
        logger.info("Attempt to get subtree roots, this may fail because lightwalletd may not support DAG sync.")
        let stream = service.getSubtreeRoots(request)
        
        var roots: [SubtreeRoot] = []
        var err: Error?
        
        do {
            for try await subtreeRoot in stream {
                roots.append(subtreeRoot)
            }
        } catch {
            logger.debug("getSubtreeRoots failed with error \(error.localizedDescription)")
            err = error
        }

        // In case of error, the lightwalletd doesn't support DAG sync -> switching to linear sync.
        // Likewise, no subtree roots results in switching to linear sync.
        if err != nil || roots.isEmpty {
            logger.info("DAG sync is not possible, switching to linear sync.")
            await context.update(state: .computeSyncControlData)
        } else {
            logger.info("Sapling tree has \(roots.count) subtrees")
            do {
                try await rustBackend.putSaplingSubtreeRoots(startIndex: UInt64(request.startIndex), roots: roots)
                
                // TODO: [#1167] Switching back to linear sync for now before step 3 & 4 are implemented
                // https://github.com/zcash/ZcashLightClientKit/issues/1167
                await context.update(state: .computeSyncControlData)
            } catch {
                logger.debug("putSaplingSubtreeRoots failed with error \(error.localizedDescription)")
                throw ZcashError.compactBlockProcessorPutSaplingSubtreeRoots(error)
            }
        }
        
        return context
    }

    func stop() async { }
}
