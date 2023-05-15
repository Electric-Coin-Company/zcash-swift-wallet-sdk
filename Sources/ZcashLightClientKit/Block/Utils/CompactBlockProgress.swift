//
//  CompactBlockProgress.swift
//  
//
//  Created by Michal Fousek on 11.05.2023.
//

import Foundation

final actor CompactBlockProgress {
    static let zero = CompactBlockProgress()
    
    enum Action: Equatable {
        case enhance
        case fetch
        case scan
        
        func weight() -> Float {
            switch self {
            case .enhance: return 0.08
            case .fetch: return 0.02
            case .scan: return 0.9
            }
        }
    }
    
    var actionProgresses: [Action: Float] = [:]

    var progress: Float {
        var overallProgress = Float(0)
        actionProgresses.forEach { key, value in
            overallProgress += value * key.weight()
        }
        
        return overallProgress
    }
    
    func event(_ event: CompactBlockProcessor.Event) -> Bool {
        guard case .progressPartialUpdate(let update) = event else {
            return false
        }
        
        switch update {
        case .syncing(let progress):
            actionProgresses[.scan] = progress.progress
        case .enhance(let progress):
            actionProgresses[.enhance] = progress.progress
        case .fetch(let progress):
            actionProgresses[.fetch] = progress
        }
        
        return true
    }
    
    func reset() {
        actionProgresses.removeAll()
    }
}

enum CompactBlockProgressUpdate: Equatable {
    case syncing(_ progress: BlockProgress)
    case enhance(_ progress: EnhancementProgress)
    case fetch(_ progress: Float)
}
