//
//  ValidatePreviousWalletSessionAction.swift
//  
//
//  Created by Lukáš Korba on 02.08.2023.
//

import Foundation

final class ValidatePreviousWalletSessionAction {
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        logger = container.resolve(Logger.self)
    }
}

extension ValidatePreviousWalletSessionAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        logger.info("Getting the suggested scan ranges from the wallet database.")
        let scanRanges = try await rustBackend.suggestScanRanges()
        
        print("__LD count \(scanRanges.count) first range \(scanRanges.first)")
        
        // Run the following loop until the wallet's view of the chain tip
        // as of the previous wallet session is valid.
//        while true {
            // If there is a range of blocks that needs to be verified, it will always
            // be returned as the first element of the vector of suggested ranges.
        if let firstRange = scanRanges.first {
            //if firstRange.priority == .verify {
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

            if scanRanges.count == 1 {
                print("cool")
            }
            
            
                await context.update(lastScannedHeight: lowerBound)
                await context.update(lastDownloadedHeight: lowerBound)
                await context.update(syncControlData: syncControlData)
            await context.update(totalProgressRange: lowerBound...upperBound)

                await context.update(state: .download)
//            } else {
//                print("cool")
//            }
        } else {
            await context.update(state: .finished)
        }
//            } else {
//                // Nothing to verify; break out of the loop
//                break
//            }
//        }
        
        // TODO: [#1171] Switching back to linear sync for now before step 7 are implemented
        // https://github.com/zcash/ZcashLightClientKit/issues/1171
//        await context.update(state: .computeSyncControlData)

        return context
    }

    func stop() async { }
}
