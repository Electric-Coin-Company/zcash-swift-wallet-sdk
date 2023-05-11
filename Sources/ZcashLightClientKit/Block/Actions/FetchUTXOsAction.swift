//
//  FetchUTXOsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class FetchUTXOsAction {
    let utxoFetcher: UTXOFetcher
    init(container: DIContainer) {
        utxoFetcher = container.resolve(UTXOFetcher.self)
    }
}

extension FetchUTXOsAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessorNG.Event) async -> Void) async throws -> ActionContext {
        if let range = await context.syncRanges.fetchUTXORange {
            let result = try await utxoFetcher.fetch(at: range)
            await didUpdate(.storedUTXOs(result))
        }
        await context.update(state: .handleSaplingParams)
        return context
    }

    func stop() async { }
}
