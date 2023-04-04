//
//  CombineSynchronizer.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

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
    ) -> SinglePublisher<Initializer.InitializationResult, Error>

    func start(retry: Bool) -> CompletablePublisher<Error>
    func stop() -> CompletablePublisher<Never>

    func getSaplingAddress(accountIndex: Int) -> SinglePublisher<SaplingAddress, Error>
    func getUnifiedAddress(accountIndex: Int) -> SinglePublisher<UnifiedAddress, Error>
    func getTransparentAddress(accountIndex: Int) -> SinglePublisher<TransparentAddress, Error>

    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) -> SinglePublisher<PendingTransactionEntity, Error>

    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) -> SinglePublisher<PendingTransactionEntity, Error>

    func cancelSpend(transaction: PendingTransactionEntity) -> SinglePublisher<Bool, Never>

    var pendingTransactions: SinglePublisher<[PendingTransactionEntity], Never> { get }
    var clearedTransactions: SinglePublisher<[ZcashTransaction.Overview], Never> { get }
    var sentTransactions: SinglePublisher<[ZcashTransaction.Sent], Never> { get }
    var receivedTransactions: SinglePublisher<[ZcashTransaction.Received], Never> { get }

    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository

    func getMemos(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[Memo], Error>
    func getMemos(for receivedTransaction: ZcashTransaction.Received) -> SinglePublisher<[Memo], Error>
    func getMemos(for sentTransaction: ZcashTransaction.Sent) -> SinglePublisher<[Memo], Error>

    func getRecipients(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[TransactionRecipient], Never>
    func getRecipients(for transaction: ZcashTransaction.Sent) -> SinglePublisher<[TransactionRecipient], Never>

    func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) -> SinglePublisher<[ZcashTransaction.Overview], Error>

    func latestHeight() -> SinglePublisher<BlockHeight, Error>

    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) -> SinglePublisher<RefreshedUTXOs, Error>

    func getTransparentBalance(accountIndex: Int) -> SinglePublisher<WalletBalance, Error>
    func getShieldedBalance(accountIndex: Int) -> SinglePublisher<Zatoshi, Error>
    func getShieldedVerifiedBalance(accountIndex: Int) -> SinglePublisher<Zatoshi, Error>

    func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error>
    func wipe() -> CompletablePublisher<Error>
}
