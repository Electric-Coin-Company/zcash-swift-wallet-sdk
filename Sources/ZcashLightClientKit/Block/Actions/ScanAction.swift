//
//  ScanAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ScanAction {
    init(container: DIContainer) { }
}

extension ScanAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext {
        // Scan in range latestScannedHeight...latestScannedHeight+batchSize.

        await context.update(state: .clearAlreadyScannedBlocks)
        return context
    }

    func stop() {

    }
}

