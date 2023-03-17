//
//  SDKSynchronizerStateHandler.swift
//  
//
//  Created by Michal Fousek on 15.03.2023.
//

import Combine
import Foundation
import XCTest
@testable import ZcashLightClientKit

class SDKSynchronizerSyncStatusHandler {
    enum StatusIdentifier: String {
        case unprepared
        case syncing
        case enhancing
        case fetching
        case synced
        case stopped
        case disconnected
        case error
    }

    private let queue = DispatchQueue(label: "SDKSynchronizerSyncStatusHandler")
    private var cancellables: [AnyCancellable] = []

    func subscribe(to stateStream: AnyPublisher<SynchronizerState, Never>, expectations: [StatusIdentifier: XCTestExpectation]) {
        stateStream
            .receive(on: queue)
            .map { $0.syncStatus }
            .sink { status in expectations[status.identifier]?.fulfill() }
            .store(in: &cancellables)
    }
}

extension SyncStatus {
    var identifier: SDKSynchronizerSyncStatusHandler.StatusIdentifier {
        switch self {
        case .unprepared: return .unprepared
        case .syncing: return .syncing
        case .enhancing: return .enhancing
        case .fetching: return .fetching
        case .synced: return .synced
        case .stopped: return .stopped
        case .disconnected: return .disconnected
        case .error: return .error
        }
    }
}
