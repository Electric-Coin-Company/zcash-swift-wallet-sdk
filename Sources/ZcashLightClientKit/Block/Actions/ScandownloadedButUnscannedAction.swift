//
//  ScandownloadedButUnscannedAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ScandownloadedButUnscannedAction {
    init() { }
}

extension ScandownloadedButUnscannedAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        if let downloadedButUnscannedRange = await context.syncRanges.downloadedButUnscannedRange {
            // Use `BlockScanner` to do the scanning in this range.
        }

        await context.update(state: .download)
        return context
    }
}
