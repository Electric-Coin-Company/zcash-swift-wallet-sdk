//
//  Action.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

actor ActionContext {
    var state: CBPState
    var syncRanges: SyncRanges

    init(state: CBPState) {
        self.state = state
        syncRanges = SyncRanges.empty
    }

    func update(state: CBPState) async {
        self.state = state
    }
}

enum CBPState: CaseIterable {
    case validateServer
    case computeSyncRanges
    case checksBeforeSync
    case scanDownloaded
    case download
    case validate
    case scan
    case clearAlreadyScannedBlocks
    case enhance
    case fetchUTXO
    case handleSaplingParams
    case clearCache
    case finished
    case failed
    case stopped
}

enum ActionProgress {
    case scan
}

protocol Action {
    // When any action is created it can get `DIContainer` and resolve any depedencies it requires.

    // Every action uses `context` to get some informartion like download range.
    //
    // `didUpdate` is closure that action use to tell CBP that some part of the work is done. For example if download action would like to
    // update progress on every block downloaded it can use this closure. Also if action doesn't need to update progress on partial work it doesn't
    // need to use this closure at all.
    //
    // Each action updates context accordingly. It should at least set new state. Reason for this is that action can return different states for
    // different conditions. And action is the thing that knows these conditions.

    func run(with context: ActionContext, didUpdate: @escaping (ActionProgress) async -> Void) async throws -> ActionContext
}
