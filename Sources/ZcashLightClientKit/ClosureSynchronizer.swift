//
//  ClosureSynchronizer.swift
//  
//
//  Created by Michal Fousek on 20.03.2023.
//

import Combine
import Foundation

/// This defines closure-based API for the SDK. It's expected that the implementation of this protocol is only a very thin layer that translates async
/// API defined in `Synchronizer` to closure-based API. And it doesn't do anything else. It's here so each client can choose the API that suits its
/// case the best.
///
/// If you are looking for documentation for a specific method or property look for it in the `Synchronizer` protocol.
public protocol ClosureSynchronizer {
    var alias: ZcashSynchronizerAlias { get }

    var latestState: SynchronizerState { get }
    var connectionState: ConnectionState { get }

    var stateStream: AnyPublisher<SynchronizerState, Never> { get }
    var eventStream: AnyPublisher<SynchronizerEvent, Never> { get }

    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
        completion: @escaping (Result<Initializer.InitializationResult, Error>) -> Void
    )

    func start(retry: Bool, completion: @escaping (Error?) -> Void)
    func stop()

    func getSaplingAddress(accountIndex: Int, completion: @escaping (Result<SaplingAddress, Error>) -> Void)
    func getUnifiedAddress(accountIndex: Int, completion: @escaping (Result<UnifiedAddress, Error>) -> Void)
    func getTransparentAddress(accountIndex: Int, completion: @escaping (Result<TransparentAddress, Error>) -> Void)

    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    )

    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    )

    func pendingTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void)
    func clearedTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void)
    func sentTranscations(completion: @escaping ([ZcashTransaction.Overview]) -> Void)
    func receivedTransactions(completion: @escaping ([ZcashTransaction.Overview]) -> Void)
    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository
    func getMemos(for transaction: ZcashTransaction.Overview, completion: @escaping (Result<[Memo], Error>) -> Void)
    func getRecipients(for transaction: ZcashTransaction.Overview, completion: @escaping ([TransactionRecipient]) -> Void)

    func allConfirmedTransactions(
        from transaction: ZcashTransaction.Overview,
        limit: Int,
        completion: @escaping (Result<[ZcashTransaction.Overview], Error>) -> Void
    )

    func latestHeight(completion: @escaping (Result<BlockHeight, Error>) -> Void)

    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight, completion: @escaping (Result<RefreshedUTXOs, Error>) -> Void)

    func getTransparentBalance(accountIndex: Int, completion: @escaping (Result<WalletBalance, Error>) -> Void)

    func getShieldedBalance(accountIndex: Int, completion: @escaping (Result<Zatoshi, Error>) -> Void)

    func getShieldedVerifiedBalance(accountIndex: Int, completion: @escaping (Result<Zatoshi, Error>) -> Void)

    /*
     It can be missleading that these two methods are returning Publisher even this protocol is closure based. Reason is that Synchronizer doesn't
     provide different implementations for these two methods. So Combine it is even here.
     */
    func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error>
    func wipe() -> CompletablePublisher<Error>
}
