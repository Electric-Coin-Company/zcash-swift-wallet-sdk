//
//  AfterSyncHooksManager.swift
//  
//
//  Created by Michal Fousek on 20.02.2023.
//

import Foundation

class AfterSyncHooksManager {
    struct WipeContext {
        let pendingDbURL: URL
        let prewipe: () -> Void
        let completion: (Error?) -> Void
    }

    enum Hook: Equatable, Hashable {
        case wipe(WipeContext)
        case anotherSync

        static func == (lhs: Hook, rhs: Hook) -> Bool {
            switch (lhs, rhs) {
            case (.wipe, .wipe):
                return true
            case (.anotherSync, .anotherSync):
                return true
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .wipe: hasher.combine(0)
            case .anotherSync: hasher.combine(1)
            }
        }

        static var emptyWipe: Hook {
            return .wipe(
                WipeContext(
                    pendingDbURL: URL(fileURLWithPath: "/"),
                    prewipe: { },
                    completion: { _ in }
                )
            )
        }
    }

    private var hooks: Set<Hook> = []

    init() { }

    func insert(hook: Hook) {
        hooks.insert(hook)
    }

    func shouldExecuteWipeHook() -> WipeContext? {
        if case let .wipe(wipeContext) = hooks.first(where: { $0 == Hook.emptyWipe }) {
            return wipeContext
        } else {
            return nil
        }
    }

    func shouldExecuteAnotherSyncHook() -> Bool {
        return hooks.first(where: { $0 == .anotherSync }) != nil
    }
}
