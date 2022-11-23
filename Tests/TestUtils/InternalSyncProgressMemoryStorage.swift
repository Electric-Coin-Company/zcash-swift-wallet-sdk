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

    func bool(forKey defaultName: String) -> Bool {
        return boolStorage[defaultName, default: false]
    }

    func integer(forKey defaultName: String) -> Int {
        return storage[defaultName, default: 0]
    }

    func set(_ value: Int, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func set(_ value: Bool, forKey defaultName: String) {
        boolStorage[defaultName] = value
    }

    func synchronize() -> Bool { true }
}
