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
        AsyncToClosureGateway.executeThrowingAction(completion) {
            return try await self.synchronizer.prepare(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
        }
    }

    public func start(retry: Bool, completion: @escaping (Error?) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.start(retry: retry)
        }
    }

    public func stop() {
        synchronizer.stop()
    }

    public func getSaplingAddress(accountIndex: Int, completion: @escaping (Result<SaplingAddress, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getSaplingAddress(accountIndex: accountIndex)
        }
    }

    public func getUnifiedAddress(accountIndex: Int, completion: @escaping (Result<UnifiedAddress, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getUnifiedAddress(accountIndex: accountIndex)
        }
    }

    public func getTransparentAddress(accountIndex: Int, completion: @escaping (Result<TransparentAddress, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getTransparentAddress(accountIndex: accountIndex)
        }
    }

    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    ) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        }
    }

    public func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    ) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.shieldFunds(spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        }
    }

    public func pendingTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void) {
        AsyncToClosureGateway.executeAction(completion) {
            await self.synchronizer.pendingTransactions
        }
    }

    public func clearedTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void) {
        AsyncToClosureGateway.executeAction(completion) {
            await self.synchronizer.transactions
        }
    }

    public func sentTranscations(completion: @escaping ([ZcashTransaction.Overview]) -> Void) {
        AsyncToClosureGateway.executeAction(completion) {
            await self.synchronizer.sentTransactions
        }
    }

    public func receivedTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void) {
        AsyncToClosureGateway.executeAction(completion) {
            await self.synchronizer.receivedTransactions
        }
    }
    
    public func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository { synchronizer.paginatedTransactions(of: kind) }

    public func getMemos(for transaction: ZcashTransaction.Overview, completion: @escaping (Result<[Memo], Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getMemos(for: transaction)
        }
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview, completion: @escaping ([TransactionRecipient]) -> Void) {
        AsyncToClosureGateway.executeAction(completion) {
            await self.synchronizer.getRecipients(for: transaction)
        }
    }

    public func allConfirmedTransactions(
        from transaction: ZcashTransaction.Overview,
        limit: Int,
        completion: @escaping (Result<[ZcashTransaction.Overview], Error>) -> Void
    ) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.allTransactions(from: transaction, limit: limit)
        }
    }

    public func latestHeight(completion: @escaping (Result<BlockHeight, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.latestHeight()
        }
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight, completion: @escaping (Result<RefreshedUTXOs, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.refreshUTXOs(address: address, from: height)
        }
    }

    public func getTransparentBalance(accountIndex: Int, completion: @escaping (Result<WalletBalance, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getTransparentBalance(accountIndex: accountIndex)
        }
    }

    public func getShieldedBalance(accountIndex: Int, completion: @escaping (Result<Zatoshi, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getShieldedBalance(accountIndex: accountIndex)
        }
    }

    public func getShieldedVerifiedBalance(accountIndex: Int, completion: @escaping (Result<Zatoshi, Error>) -> Void) {
        AsyncToClosureGateway.executeThrowingAction(completion) {
            try await self.synchronizer.getShieldedVerifiedBalance(accountIndex: accountIndex)
        }
    }

    /*
     It can be missleading that these two methods are returning Publisher even this protocol is closure based. Reason is that Synchronizer doesn't
     provide different implementations for these two methods. So Combine it is even here.
     */
    public func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error> { synchronizer.rewind(policy) }
    public func wipe() -> CompletablePublisher<Error> { synchronizer.wipe() }
}
