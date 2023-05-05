//
//  DownloadAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class DownloadAction {
    init() { }
}

extension DownloadAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // Use `BlockDownloader` to set download limit to latestScannedHeight + (2*batchSize) (after parallel is merged).
        // And start download.

        await context.update(state: .validate)
        return context
    }
}
