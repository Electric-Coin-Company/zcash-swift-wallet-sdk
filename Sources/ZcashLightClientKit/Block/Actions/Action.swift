//
//  Action.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

actor ActionContext {
    var state: CBPState
    var prevState: CBPState?
    var syncControlData: SyncControlData
    var totalProgressRange: CompactBlockRange = 0...0
    var lastDownloadedHeight: BlockHeight?
    var lastEnhancedHeight: BlockHeight?

    init(state: CBPState) {
        self.state = state
        syncControlData = SyncControlData.empty
    }

    func update(state: CBPState) async {
        prevState = self.state
        self.state = state
    }
    func update(syncControlData: SyncControlData) async { self.syncControlData = syncControlData }
    func update(totalProgressRange: CompactBlockRange) async { self.totalProgressRange = totalProgressRange }
    func update(lastDownloadedHeight: BlockHeight) async { self.lastDownloadedHeight = lastDownloadedHeight }
    func update(lastEnhancedHeight: BlockHeight?) async { self.lastEnhancedHeight = lastEnhancedHeight }
}

enum CBPState: CaseIterable {
    case idle
    case migrateLegacyCacheDB
    case validateServer
    case updateSubtreeRoots
    case computeSyncControlData
    case download
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

protocol Action {
    /// If this is true and action fails with error then blocks cache is cleared.
    var removeBlocksCacheWhenFailed: Bool { get }

    // When any action is created it can get `DIContainer` and resolve any depedencies it requires.
    // Every action uses `context` to get some informartion like download range.
    //
    // `didUpdate` is closure that action use to tell CBP that some part of the work is done. For example if download action would like to
    // update progress on every block downloaded it can use this closure. Also if action doesn't need to update progress on partial work it doesn't
    // need to use this closure at all.
    //
    // Each action updates context accordingly. It should at least set new state. Reason for this is that action can return different states for
    // different conditions. And action is the thing that knows these conditions.
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext

    // Should be called on each existing action when processor wants to stop. Some actions may do it's own background work.
    func stop() async
}
