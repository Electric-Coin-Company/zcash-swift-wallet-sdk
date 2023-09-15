//
//  CompactBlockProgress.swift
//  
//
//  Created by Michal Fousek on 11.05.2023.
//

import Foundation

final actor CompactBlockProgress {
    static let zero = CompactBlockProgress()

    var progress: ScanProgress = .init(numerator: 0, denominator: 0)

    func hasProgressUpdated(_ event: CompactBlockProcessor.Event) -> Bool {
        guard case .syncProgress(let update) = event else {
            return false
        }

        progress = update
        
        return true
    }
}
