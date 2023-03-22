//
//  ClosureSDKSynchronizer.swift
//  
//
//  Created by Michal Fousek on 20.03.2023.
//

import Combine
import Foundation

/// This is a super thin layer that implements the `ClosureSynchronizer` protocol and translates the async API defined in `Synchronizer` to
/// closure-based API. And it doesn't do anything else. It doesn't keep any state.  It's here so each client can choose the API that suits its case
/// the best. And usage of this can be combined with usage of `CombineSDKSynchronizer`. So devs can really choose the best SDK API for each part of the
/// client app.
///
/// If you are looking for documentation for a specific method or property look for it in the `Synchronizer` protocol.
public struct ClosureSDKSynchronizer {
    private let synchronizer: Synchronizer

    public init(synchronizer: Synchronizer) {
        self.synchronizer = synchronizer
    }
}

extension ClosureSDKSynchronizer: ClosureSynchronizer {
    public var alias: ZcashSynchronizerAlias { synchronizer.alias }

    public var latestState: SynchronizerState { synchronizer.latestState }
    public var connectionState: ConnectionState { synchronizer.connectionState }

    public var stateStream: AnyPublisher<SynchronizerState, Never> { synchronizer.stateStream }
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { synchronizer.eventStream }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
        completion: @escaping (Result<Initializer.InitializationResult, Error>) -> Void
    ) {
        executeThrowingAction(completion) {
            return try await self.synchronizer.prepare(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
        }
    }

    public func start(retry: Bool, completion: @escaping (Error?) -> Void) {
        executeThrowingAction(completion) {
            try await self.synchronizer.start(retry: retry)
        }
    }

    public func stop(completion: @escaping () -> Void) {
        executeAction(completion) {
            await self.synchronizer.stop()
        }
    }

    public func getSaplingAddress(accountIndex: Int, completion: @escaping (SaplingAddress?) -> Void) {
        executeAction(completion) {
            await self.synchronizer.getSaplingAddress(accountIndex: accountIndex)
        }
    }

    public func getUnifiedAddress(accountIndex: Int, completion: @escaping (UnifiedAddress?) -> Void) {
        executeAction(completion) {
            await self.synchronizer.getUnifiedAddress(accountIndex: accountIndex)
        }
    }

    public func getTransparentAddress(accountIndex: Int, completion: @escaping (TransparentAddress?) -> Void) {
        executeAction(completion) {
            await self.synchronizer.getTransparentAddress(accountIndex: accountIndex)
        }
    }

    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?,
        completion: @escaping (Result<PendingTransactionEntity, Error>) -> Void
    ) {
        executeThrowingAction(completion) {
            try await self.synchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        }
    }

    public func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi,
        completion: @escaping (Result<PendingTransactionEntity, Error>) -> Void
    ) {
        executeThrowingAction(completion) {
            try await self.synchronizer.shieldFunds(spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        }
    }

    public func cancelSpend(transaction: PendingTransactionEntity) -> Bool { synchronizer.cancelSpend(transaction: transaction) }

    public var pendingTransactions: [PendingTransactionEntity] { synchronizer.pendingTransactions }
    public var clearedTransactions: [ZcashTransaction.Overview] { synchronizer.clearedTransactions }
    public var sentTransactions: [ZcashTransaction.Sent] { synchronizer.sentTransactions }
    public var receivedTransactions: [ZcashTransaction.Received] { synchronizer.receivedTransactions }
    
    public func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository { synchronizer.paginatedTransactions(of: kind) }

    public func getMemos(for transaction: ZcashTransaction.Overview) throws -> [Memo] { try synchronizer.getMemos(for: transaction) }
    public func getMemos(for receivedTransaction: ZcashTransaction.Received) throws -> [Memo] { try synchronizer.getMemos(for: receivedTransaction) }
    public func getMemos(for sentTransaction: ZcashTransaction.Sent) throws -> [Memo] { try synchronizer.getMemos(for: sentTransaction) }

    public func getRecipients(for transaction: ZcashTransaction.Overview) -> [TransactionRecipient] { synchronizer.getRecipients(for: transaction) }
    public func getRecipients(for transaction: ZcashTransaction.Sent) -> [TransactionRecipient] { synchronizer.getRecipients(for: transaction) }

    public func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) throws -> [ZcashTransaction.Overview] {
        try synchronizer.allConfirmedTransactions(from: transaction, limit: limit)
    }

    public func latestHeight(completion: @escaping (Result<BlockHeight, Error>) -> Void) {
        executeThrowingAction(completion) {
            try await self.synchronizer.latestHeight()
        }
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight, completion: @escaping (Result<RefreshedUTXOs, Error>) -> Void) {
        executeThrowingAction(completion) {
            try await self.synchronizer.refreshUTXOs(address: address, from: height)
        }
    }

    public func getTransparentBalance(accountIndex: Int, completion: @escaping (Result<WalletBalance, Error>) -> Void) {
        executeThrowingAction(completion) {
            try await self.synchronizer.getTransparentBalance(accountIndex: accountIndex)
        }
    }

    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    public func getShieldedBalance(accountIndex: Int) -> Int64 { synchronizer.getShieldedBalance(accountIndex: accountIndex) }
    public func getShieldedBalance(accountIndex: Int) -> Zatoshi { synchronizer.getShieldedBalance(accountIndex: accountIndex) }

    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    public func getShieldedVerifiedBalance(accountIndex: Int) -> Int64 { synchronizer.getShieldedVerifiedBalance(accountIndex: accountIndex) }
    public func getShieldedVerifiedBalance(accountIndex: Int) -> Zatoshi { synchronizer.getShieldedVerifiedBalance(accountIndex: accountIndex) }

    /*
     It can be missleading that these two methods are returning Publisher even this protocol is closure based. Reason is that Synchronizer doesn't
     provide different implementations for these two methods. So Combine it is even here.
     */
    public func rewind(_ policy: RewindPolicy) -> Completable<Error> { synchronizer.rewind(policy) }
    public func wipe() -> Completable<Error> { synchronizer.wipe() }
}

extension ClosureSDKSynchronizer {
    private func executeAction(_ completion: @escaping () -> Void, action: @escaping () async -> Void) {
        Task {
            await action()
            completion()
        }
    }

    private func executeAction<R>(_ completion: @escaping (R) -> Void, action: @escaping () async -> R) {
        Task {
            let result = await action()
            completion(result)
        }
    }

    private func executeThrowingAction(_ completion: @escaping (Error?) -> Void, action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    private func executeThrowingAction<R>(_ completion: @escaping (Result<R, Error>) -> Void, action: @escaping () async throws -> R) {
        Task {
            do {
                let result = try await action()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
