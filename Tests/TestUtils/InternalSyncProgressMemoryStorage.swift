//
//  InternalSyncProgressMemoryStorage.swift
//  
//
//  Created by Michal Fousek on 24.11.2022.
//

import Foundation
@testable import ZcashLightClientKit

class InternalSyncProgressMemoryStorage: InternalSyncProgressStorage {
    private var boolStorage: [String: Bool] = [:]
    private var storage: [String: Int] = [:]

    func initialize() async throws { }

    func bool(for key: String) async throws -> Bool {
        return boolStorage[key, default: false]
    }

    func integer(for key: String) async throws -> Int {
        return storage[key, default: 0]
    }

    func set(_ value: Int, for key: String) async throws {
        storage[key] = value
    }

    func set(_ value: Bool, for key: String) async throws {
        boolStorage[key] = value
    }

    func synchronize() -> Bool { true }
}
