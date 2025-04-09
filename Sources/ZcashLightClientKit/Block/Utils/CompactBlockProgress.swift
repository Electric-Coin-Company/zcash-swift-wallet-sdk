//
//  CompactBlockProgress.swift
//  
//
//  Created by Michal Fousek on 11.05.2023.
//

import Foundation

final actor CompactBlockProgress {
    static let zero = CompactBlockProgress()

    var syncProgress: Float = 0.0
    var recoveryProgress: Float?

    func hasProgressUpdated(_ event: CompactBlockProcessor.Event) -> Bool {
        guard case let .syncProgress(syncProgress, recoveryProgress) = event else {
            return false
        }

        self.syncProgress = syncProgress
        self.recoveryProgress = recoveryProgress

        return true
    }
}
