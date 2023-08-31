//
//  UpdateSubtreeRootsAction.swift
//  
//
//  Created by Lukas Korba on 01.08.2023.
//

import Foundation

final class UpdateSubtreeRootsAction {
    let configProvider: CompactBlockProcessor.ConfigProvider
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer, configProvider: CompactBlockProcessor.ConfigProvider) {
        self.configProvider = configProvider
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
        request.maxEntries = await configProvider.config.network.networkType == .testnet ? 65536 : 0
        
        logger.info("Attempt to get subtree roots, this may fail because lightwalletd may not support Spend before Sync.")
        let stream = service.getSubtreeRoots(request)
        
        var roots: [SubtreeRoot] = []
        var err: Error?
        
        do {
            for try await subtreeRoot in stream {
                roots.append(subtreeRoot)
            }
        } catch ZcashError.serviceSubtreeRootsStreamFailed(LightWalletServiceError.timeOut) {
            throw ZcashError.serviceSubtreeRootsStreamFailed(LightWalletServiceError.timeOut)
        } catch {
            logger.debug("getSubtreeRoots failed with error \(error.localizedDescription)")
            err = error
        }

        // In case of error, the lightwalletd doesn't support Spend before Sync -> switching to linear sync.
        // Likewise, no subtree roots results in switching to linear sync.
        if err != nil || roots.isEmpty {
            logger.info("Spend before Sync is not possible, switching to linear sync.")
            await context.update(supportedSyncAlgorithm: .linear)
            await context.update(state: .computeSyncControlData)
        } else {
            await context.update(supportedSyncAlgorithm: .spendBeforeSync)
            logger.info("Sapling tree has \(roots.count) subtrees")
            do {
                try await rustBackend.putSaplingSubtreeRoots(startIndex: UInt64(request.startIndex), roots: roots)
                
                await context.update(state: .updateChainTip)
            } catch {
                logger.debug("putSaplingSubtreeRoots failed with error \(error.localizedDescription)")
                throw ZcashError.compactBlockProcessorPutSaplingSubtreeRoots(error)
            }
        }
        
        return context
    }

    func stop() async { }
}
