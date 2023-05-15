//
//  FetchUTXOsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class FetchUTXOsAction {
    let utxoFetcher: UTXOFetcher
    let logger: Logger

    init(container: DIContainer) {
        utxoFetcher = container.resolve(UTXOFetcher.self)
        logger = container.resolve(Logger.self)
    }
}

extension FetchUTXOsAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        if let range = await context.syncRanges.fetchUTXORange {
            logger.debug("Fetching UTXO with range: \(range.lowerBound)...\(range.upperBound)")
            let result = try await utxoFetcher.fetch(at: range) { fetchProgress in
                await didUpdate(.progressPartialUpdate(.fetch(fetchProgress)))
            }
            await didUpdate(.storedUTXOs(result))
        }
        
        await context.update(state: .handleSaplingParams)
        return context
    }

    func stop() async { }
}
