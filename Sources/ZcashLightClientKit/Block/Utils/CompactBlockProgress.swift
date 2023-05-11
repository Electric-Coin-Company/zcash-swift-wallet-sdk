//
//  CompactBlockProgress.swift
//  
//
//  Created by Michal Fousek on 11.05.2023.
//

import Foundation

public enum CompactBlockProgress {
    case syncing(_ progress: BlockProgress)
    case enhance(_ progress: EnhancementProgress)
    case fetch

    public var progress: Float {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.progress
        case .enhance(let enhancementProgress):
            return enhancementProgress.progress
        default:
            return 0
        }
    }

    public var progressHeight: BlockHeight? {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.progressHeight
        case .enhance(let enhancementProgress):
            return enhancementProgress.lastFoundTransaction?.minedHeight
        default:
            return 0
        }
    }

    public var blockDate: Date? {
        if case .enhance(let enhancementProgress) = self, let time = enhancementProgress.lastFoundTransaction?.blockTime {
            return Date(timeIntervalSince1970: time)
        }

        return nil
    }

    public var targetHeight: BlockHeight? {
        switch self {
        case .syncing(let blockProgress):
            return blockProgress.targetHeight
        default:
            return nil
        }
    }
}
