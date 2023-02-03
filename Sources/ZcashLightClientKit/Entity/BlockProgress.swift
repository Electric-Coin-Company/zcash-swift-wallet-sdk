//
//  BlockProgress.swift
//  
//
//  Created by Michal Fousek on 03.02.2023.
//

import Foundation

public struct BlockProgress: Equatable {
    public var startHeight: BlockHeight
    public var targetHeight: BlockHeight
    public var progressHeight: BlockHeight

    public var progress: Float {
        let overall = self.targetHeight - self.startHeight

        return overall > 0 ? Float((self.progressHeight - self.startHeight)) / Float(overall) : 0
    }
}

public extension BlockProgress {
    static let nullProgress = BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0)
}
