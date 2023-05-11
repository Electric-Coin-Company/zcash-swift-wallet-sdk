//
//  FetchUTXOsAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class FetchUTXOsAction {
    init(container: DIContainer) { }
}

extension FetchUTXOsAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProgress) async -> Void) async throws -> ActionContext {
        // Use `UTXOFetcher` to fetch UTXOs.
        
        await context.update(state: .handleSaplingParams)
        return context
    }

    func stop() async { }
}
