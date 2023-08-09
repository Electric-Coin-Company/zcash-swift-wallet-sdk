//
//  ProcessSuggestedScanRangesAction.swift
//  
//
//  Created by Lukáš Korba on 02.08.2023.
//

import Foundation

final class ProcessSuggestedScanRangesAction {
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        logger = container.resolve(Logger.self)
    }
}

extension ProcessSuggestedScanRangesAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        logger.info("Getting the suggested scan ranges from the wallet database.")
        let scanRanges = try await rustBackend.suggestScanRanges()
        
        if let firstRange = scanRanges.first {
            let lowerBound = firstRange.range.lowerBound - 1
            let upperBound = firstRange.range.upperBound - 1
            
            let syncControlData = SyncControlData(
                latestBlockHeight: upperBound,
                latestScannedHeight: lowerBound,
                firstUnenhancedHeight: lowerBound + 1
            )
            
            logger.debug("""
                Init numbers:
                latestBlockHeight [BC]:         \(upperBound)
                latestScannedHeight [DB]:       \(lowerBound)
                firstUnenhancedHeight [DB]:     \(lowerBound + 1)
                """)
            
            await context.update(lastScannedHeight: lowerBound)
            await context.update(lastDownloadedHeight: lowerBound)
            await context.update(syncControlData: syncControlData)
            await context.update(totalProgressRange: lowerBound...upperBound)
            
            // If there is a range of blocks that needs to be verified, it will always
            // be returned as the first element of the vector of suggested ranges.
            if firstRange.priority == .verify {
                await context.update(requestedRewindHeight: lowerBound + 1)
                await context.update(state: .rewind)
            } else {
                await context.update(state: .download)
            }
        } else {
            await context.update(state: .finished)
        }
        
        return context
    }

    func stop() async { }
}
