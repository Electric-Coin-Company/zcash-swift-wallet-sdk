//
//  SDKSynchronizerNonAsync.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

public class SDKSynchronizerNonAsync {
    private let synchronizer: Synchronizer

    public init(synchronizer: Synchronizer) {
        self.synchronizer = synchronizer
    }
}

extension SDKSynchronizerNonAsync: SynchronizerNonAsync {
    public var stateStream: AnyPublisher<SynchronizerState, Never> { synchronizer.stateStream }
    public var latestState: SynchronizerState { synchronizer.latestState }
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { synchronizer.eventStream }
    public var connectionState: ConnectionState { synchronizer.connectionState }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
        completion: @escaping (Result<Initializer.InitializationResult, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await synchronizer.prepare(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) -> Single<Initializer.InitializationResult, Error> {
        let subject = PassthroughSubject<Initializer.InitializationResult, Error>()
        Task {
            do {
                let result = try await synchronizer.prepare(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
                subject.send(result)
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }
        return subject.eraseToAnyPublisher()
    }

    public func start(retry: Bool, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await synchronizer.start(retry: retry)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func start(retry: Bool) -> Completable<Error> {
        let subject = PassthroughSubject<Void, Error>()
        Task {
            do {
                try await synchronizer.start(retry: retry)
                subject.send(Void())
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }
        return subject.eraseToAnyPublisher()
    }

    public func stop() {
        synchronizer.stop()
    }
}
