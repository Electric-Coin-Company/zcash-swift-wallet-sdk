//
//  CombineSynchronizer.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

/* These aliases are here to just make the API easier to read. */

// Publisher which emitts completed or error. No value is emitted.
public typealias CompletablePublisher<E: Error> = AnyPublisher<Void, E>
// Publisher that either emits one value and then finishes or it emits error.
public typealias Single = AnyPublisher

/// This defines a Combine-based API for the SDK. It's expected that the implementation of this protocol is only a very thin layer that translates
/// async API defined in `Synchronizer` to Combine-based API. And it doesn't do anything else. It's here so each client can choose the API that suits
/// its case the best.
///
/// If you are looking for documentation for a specific method or property look for it in the `Synchronizer` protocol.
public protocol CombineSynchronizer {
    var alias: ZcashSynchronizerAlias { get }

    var latestState: SynchronizerState { get }
    var connectionState: ConnectionState { get }

    var stateStream: AnyPublisher<SynchronizerState, Never> { get }
    var eventStream: AnyPublisher<SynchronizerEvent, Never> { get }

    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) -> Single<Initializer.InitializationResult, Error>

    func start(retry: Bool) -> CompletablePublisher<Error>
    func stop() -> CompletablePublisher<Never>

    func getSaplingAddress(accountIndex: Int) -> Single<SaplingAddress, Error>
    func getUnifiedAddress(accountIndex: Int) -> Single<UnifiedAddress, Error>
    func getTransparentAddress(accountIndex: Int) -> Single<TransparentAddress, Error>

    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) -> Single<PendingTransactionEntity, Error>

    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) -> Single<PendingTransactionEntity, Error>

    func cancelSpend(transaction: PendingTransactionEntity) -> Single<Bool, Never>

    var pendingTransactions: Single<[PendingTransactionEntity], Never> { get }
    var clearedTransactions: Single<[ZcashTransaction.Overview], Never> { get }
    var sentTransactions: Single<[ZcashTransaction.Sent], Never> { get }
    var receivedTransactions: Single<[ZcashTransaction.Received], Never> { get }

    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository

    func getMemos(for transaction: ZcashTransaction.Overview) -> Single<[Memo], Error>
    func getMemos(for receivedTransaction: ZcashTransaction.Received) -> Single<[Memo], Error>
    func getMemos(for sentTransaction: ZcashTransaction.Sent) -> Single<[Memo], Error>

    func getRecipients(for transaction: ZcashTransaction.Overview) -> Single<[TransactionRecipient], Never>
    func getRecipients(for transaction: ZcashTransaction.Sent) -> Single<[TransactionRecipient], Never>

    func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) -> Single<[ZcashTransaction.Overview], Error>

    func latestHeight() -> Single<BlockHeight, Error>

    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) -> Single<RefreshedUTXOs, Error>

    func getTransparentBalance(accountIndex: Int) -> Single<WalletBalance, Error>
    func getShieldedBalance(accountIndex: Int) -> Single<Zatoshi, Error>
    func getShieldedVerifiedBalance(accountIndex: Int) -> Single<Zatoshi, Error>

    func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error>
    func wipe() -> CompletablePublisher<Error>
}
