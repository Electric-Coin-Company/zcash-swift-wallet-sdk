//
//  SynchronizerNonAsync.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

/* These types are here to just make the API easier to read. */

// Publisher which emitts completed or error. No value is emitted.
public typealias Completable<E: Error> = AnyPublisher<Void, E>
// Publisher that emitts just one value.
public typealias Single = AnyPublisher

public protocol SynchronizerNonAsync {
    var stateStream: AnyPublisher<SynchronizerState, Never> { get }

    var latestState: SynchronizerState { get }

    var eventStream: AnyPublisher<SynchronizerEvent, Never> { get }

    var connectionState: ConnectionState { get }

    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
        completion: @escaping (Result<Initializer.InitializationResult, Error>) -> Void
    )

    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) -> Single<Initializer.InitializationResult, Error>

    func start(retry: Bool, completion: @escaping (Error?) -> Void)
    func start(retry: Bool) -> Completable<Error>

    func stop()
}
