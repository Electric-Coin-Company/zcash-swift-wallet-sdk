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
        walletBirthday: BlockHeight,
        for walletMode: WalletInitMode,
        completion: @escaping (Result<Initializer.InitializationResult, Error>) -> Void
    )

    func start(retry: Bool, completion: @escaping (Error?) -> Void)
    func stop()

    func getSaplingAddress(accountIndex: Int, completion: @escaping (Result<SaplingAddress, Error>) -> Void)
    func getUnifiedAddress(accountIndex: Int, completion: @escaping (Result<UnifiedAddress, Error>) -> Void)
    func getTransparentAddress(accountIndex: Int, completion: @escaping (Result<TransparentAddress, Error>) -> Void)

    /// Creates a proposal for transferring funds to the given recipient.
    ///
    /// - Parameter accountIndex: the account from which to transfer funds.
    /// - Parameter recipient: the recipient's address.
    /// - Parameter amount: the amount to send in Zatoshi.
    /// - Parameter memo: an optional memo to include as part of the proposal's transactions. Use `nil` when sending to transparent receivers otherwise the function will throw an error.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func proposeTransfer(
        accountIndex: Int,
        recipient: Recipient,
        amount: Zatoshi,
        memo: Memo?,
        completion: @escaping (Result<Proposal, Error>) -> Void
    )

    /// Creates a proposal for shielding any transparent funds received by the given account.
    ///
    /// - Parameter accountIndex: the account for which to shield funds.
    /// - Parameter shieldingThreshold: the minimum transparent balance required before a proposal will be created.
    /// - Parameter memo: an optional memo to include as part of the proposal's transactions.
    /// - Parameter transparentReceiver: a specific transparent receiver within the account
    ///             that should be the source of transparent funds. Default is `nil` which
    ///             will select whichever of the account's transparent receivers has funds
    ///             to shield.
    ///
    /// Returns the proposal, or `nil` if the transparent balance that would be shielded
    /// is zero or below `shieldingThreshold`.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func proposeShielding(
        accountIndex: Int,
        shieldingThreshold: Zatoshi,
        memo: Memo,
        transparentReceiver: TransparentAddress?,
        completion: @escaping (Result<Proposal?, Error>) -> Void
    )

    /// Creates the transactions in the given proposal.
    ///
    /// - Parameter proposal: the proposal for which to create transactions.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` associated with the account for which the proposal was created.
    ///
    /// Returns a stream of objects for the transactions that were created as part of the
    /// proposal, indicating whether they were submitted to the network or if an error
    /// occurred.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance
    /// or since the last wipe then this method throws `SynchronizerErrors.notPrepared`.
    func createProposedTransactions(
        proposal: Proposal,
        spendingKey: UnifiedSpendingKey,
        completion: @escaping (Result<AsyncThrowingStream<TransactionSubmitResult, Error>, Error>) -> Void
    )

    @available(*, deprecated, message: "Upcoming SDK 2.1 will create multiple transactions at once for some recipients.")
    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    )

    @available(*, deprecated, message: "Upcoming SDK 2.1 will create multiple transactions at once for some recipients.")
    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi,
        completion: @escaping (Result<ZcashTransaction.Overview, Error>) -> Void
    )

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

    func getAccountBalance(accountIndex: Int, completion: @escaping (Result<AccountBalance?, Error>) -> Void)

    func refreshExchangeRateUSD()

    /*
     It can be missleading that these two methods are returning Publisher even this protocol is closure based. Reason is that Synchronizer doesn't
     provide different implementations for these two methods. So Combine it is even here.
     */
    func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error>
    func wipe() -> CompletablePublisher<Error>
}
