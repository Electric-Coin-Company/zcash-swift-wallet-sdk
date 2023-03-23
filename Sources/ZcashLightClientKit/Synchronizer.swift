//
//  Synchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/5/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import Foundation

/// Represents errors thrown by a Synchronizer
public enum SynchronizerError: Error {
    case initFailed(message: String) // ZcashLightClientKit.SynchronizerError error 0.
    case notPrepared // ZcashLightClientKit.SynchronizerError error 9.
    case syncFailed // ZcashLightClientKit.SynchronizerError error 10.
    case connectionFailed(message: Error) // ZcashLightClientKit.SynchronizerError error 1.
    case generalError(message: String) // ZcashLightClientKit.SynchronizerError error 2.
    case maxRetryAttemptsReached(attempts: Int) // ZcashLightClientKit.SynchronizerError error 3.
    case connectionError(status: Int, message: String) // ZcashLightClientKit.SynchronizerError error 4.
    case networkTimeout // ZcashLightClientKit.SynchronizerError error 11.
    case uncategorized(underlyingError: Error) // ZcashLightClientKit.SynchronizerError error 5.
    case criticalError // ZcashLightClientKit.SynchronizerError error 12.
    case parameterMissing(underlyingError: Error) // ZcashLightClientKit.SynchronizerError error 6.
    case rewindError(underlyingError: Error) // ZcashLightClientKit.SynchronizerError error 7.
    case rewindErrorUnknownArchorHeight // ZcashLightClientKit.SynchronizerError error 13.
    case invalidAccount // ZcashLightClientKit.SynchronizerError error 14.
    case lightwalletdValidationFailed(underlyingError: Error) // ZcashLightClientKit.SynchronizerError error 8.
}

public enum ShieldFundsError: Error {
    case noUTXOFound
    case insuficientTransparentFunds
    case shieldingFailed(underlyingError: Error)
}

extension ShieldFundsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noUTXOFound:
            return "Could not find UTXOs for the given t-address"
        case .insuficientTransparentFunds:
            return "You don't have enough confirmed transparent funds to perform a shielding transaction."
        case .shieldingFailed(let underlyingError):
            return "Shielding transaction failed. Reason: \(underlyingError)"
        }
    }
}

/// Represent the connection state to the lightwalletd server
public enum ConnectionState {
    /// not in use
    case idle

    /// there's a connection being attempted from a non error state
    case connecting

    /// connection is established, ready to use or in use
    case online

    /// the connection is being re-established after losing it temporarily
    case reconnecting

    /// the connection has been closed
    case shutdown
}

public struct SynchronizerState: Equatable {
    public var shieldedBalance: WalletBalance
    public var transparentBalance: WalletBalance
    public var syncStatus: SyncStatus
    public var latestScannedHeight: BlockHeight

    public static var zero: SynchronizerState {
        SynchronizerState(
            shieldedBalance: .zero,
            transparentBalance: .zero,
            syncStatus: .unprepared,
            latestScannedHeight: .zero
        )
    }
}

public enum SynchronizerEvent {
    // Sent when the synchronizer finds a pendingTransaction that hast been newly mined.
    case minedTransaction(PendingTransactionEntity)
    // Sent when the synchronizer finds a mined transaction
    case foundTransactions(_ transactions: [ZcashTransaction.Overview], _ inRange: CompactBlockRange)
    // Sent when the synchronizer fetched utxos from lightwalletd attempted to store them.
    case storedUTXOs(_ inserted: [UnspentTransactionOutputEntity], _ skipped: [UnspentTransactionOutputEntity])
    // Connection state to LightwalletEndpoint changed.
    case connectionStateChanged(ConnectionState)
}

/// Primary interface for interacting with the SDK. Defines the contract that specific
/// implementations like SdkSynchronizer fulfill.
public protocol Synchronizer: AnyObject {
    /// Latest state of the SDK which can be get in synchronous manner.
    var latestState: SynchronizerState { get }

    /// reflects current connection state to LightwalletEndpoint
    var connectionState: ConnectionState { get }

    /// This stream is backed by `CurrentValueSubject`. This is primary source of information about what is the SDK doing. New values are emitted when
    /// `SyncStatus` is changed inside the SDK.
    ///
    /// Synchronization progress is part of the `SyncStatus` so this stream emits lot of values. `throttle` can be used to control amout of values
    /// delivered. Values are delivered on random background thread.
    var stateStream: AnyPublisher<SynchronizerState, Never> { get }

    /// This stream is backed by `PassthroughSubject`. Check `SynchronizerEvent` to see which events may be emitted.
    var eventStream: AnyPublisher<SynchronizerEvent, Never> { get }

    /// Initialize the wallet. The ZIP-32 seed bytes can optionally be passed to perform
    /// database migrations. most of the times the seed won't be needed. If they do and are
    /// not provided this will fail with `InitializationResult.seedRequired`. It could
    /// be the case that this method is invoked by a wallet that does not contain the seed phrase
    /// and is view-only, or by a wallet that does have the seed but the process does not have the
    /// consent of the OS to fetch the keys from the secure storage, like on background tasks.
    ///
    /// 'cache.db' and 'data.db' files are created by this function (if they
    /// do not already exist). These files can be given a prefix for scenarios where multiple wallets
    ///
    /// - Parameters:
    ///   - seed: ZIP-32 Seed bytes for the wallet that will be initialized.
    ///   - viewingKeys: Viewing key derived from seed.
    ///   - walletBirthday: Birthday of wallet.
    /// - Throws:
    /// `InitializerError.dataDbInitFailed` if the creation of the dataDb fails
    /// `InitializerError.accountInitFailed` if the account table can't be initialized.
    /// `InitializerError.aliasAlreadyInUse` if the Alias used to create this instance is already used by other instance
    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) async throws -> Initializer.InitializationResult

    /// Starts this synchronizer within the given scope.
    ///
    /// Implementations should leverage structured concurrency and
    /// cancel all jobs when this scope completes.
    func start(retry: Bool) async throws

    /// Stop this synchronizer. Implementations should ensure that calling this method cancels all jobs that were created by this instance.
    func stop() async

    /// Gets the sapling shielded address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getSaplingAddress(accountIndex: Int) async -> SaplingAddress?

    /// Gets the unified address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getUnifiedAddress(accountIndex: Int) async -> UnifiedAddress?

    /// Gets the transparent address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getTransparentAddress(accountIndex: Int) async -> TransparentAddress?
    
    /// Sends zatoshi.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` that allows spends to occur.
    /// - Parameter zatoshi: the amount to send in Zatoshi.
    /// - Parameter toAddress: the recipient's address.
    /// - Parameter memo: an `Optional<Memo>`with the memo to include as part of the transaction. send `nil` when sending to transparent receivers otherwise the function will throw an error
    ///
    /// If `prepare()` hasn't already been called since creating of synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) async throws -> PendingTransactionEntity

    /// Shields transparent funds from the given private key into the best shielded pool of the account associated to the given `UnifiedSpendingKey`.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` that allows to spend transparent funds
    /// - Parameter memo: the optional memo to include as part of the transaction.
    ///
    /// If `prepare()` hasn't already been called since creating of synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) async throws -> PendingTransactionEntity

    /// Attempts to cancel a transaction that is about to be sent. Typically, cancellation is only
    /// an option if the transaction has not yet been submitted to the server.
    /// - Parameter transaction: the transaction to cancel.
    /// - Returns: true when the cancellation request was successful. False when it is too late.
    func cancelSpend(transaction: PendingTransactionEntity) -> Bool

    /// all outbound pending transactions that have been sent but are awaiting confirmations
    var pendingTransactions: [PendingTransactionEntity] { get }

    /// all the transactions that are on the blockchain
    var clearedTransactions: [ZcashTransaction.Overview] { get }

    /// All transactions that are related to sending funds
    var sentTransactions: [ZcashTransaction.Sent] { get }

    /// all transactions related to receiving funds
    var receivedTransactions: [ZcashTransaction.Received] { get }
    
    /// A repository serving transactions in a paginated manner
    /// - Parameter kind: Transaction Kind expected from this PaginatedTransactionRepository
    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository

    /// Get all memos for `transaction`.
    func getMemos(for transaction: ZcashTransaction.Overview) throws -> [Memo]

    /// Get all memos for `receivedTransaction`.
    func getMemos(for receivedTransaction: ZcashTransaction.Received) throws -> [Memo]

    /// Get all memos for `sentTransaction`.
    func getMemos(for sentTransaction: ZcashTransaction.Sent) throws -> [Memo]

    /// Attempt to get recipients from a Transaction Overview.
    /// - parameter transaction: A transaction overview
    /// - returns the recipients or an empty array if no recipients are found on this transaction because it's not an outgoing
    /// transaction
    func getRecipients(for transaction: ZcashTransaction.Overview) -> [TransactionRecipient]
    
    /// Get the recipients for the given a sent transaction
    /// - parameter transaction: A transaction overview
    /// - returns the recipients or an empty array if no recipients are found on this transaction because it's not an outgoing
    /// transaction
    func getRecipients(for transaction: ZcashTransaction.Sent) -> [TransactionRecipient]

    /// Returns a list of confirmed transactions that preceed the given transaction with a limit count.
    /// - Parameters:
    ///     - from: the confirmed transaction from which the query should start from or nil to retrieve from the most recent transaction
    ///     - limit: the maximum amount of items this should return if available
    ///     - Returns: an array with the given Transactions or nil
    func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) throws -> [ZcashTransaction.Overview]

    /// Returns the latest block height from the provided Lightwallet endpoint
    /// Blocking
    func latestHeight() async throws -> BlockHeight

    /// Returns the latests UTXOs for the given address from the specified height on
    ///
    /// If `prepare()` hasn't already been called since creating of synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs

    /// Returns the last stored transparent balance
    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance

    /// Returns the shielded total balance (includes verified and unverified balance)
    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    func getShieldedBalance(accountIndex: Int) -> Int64

    /// Returns the shielded total balance (includes verified and unverified balance)
    func getShieldedBalance(accountIndex: Int) -> Zatoshi

    /// Returns the shielded verified balance (anchor is 10 blocks back)
    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    func getShieldedVerifiedBalance(accountIndex: Int) -> Int64

    /// Returns the shielded verified balance (anchor is 10 blocks back)
    func getShieldedVerifiedBalance(accountIndex: Int) -> Zatoshi

    /// Rescans the known blocks with the current keys.
    ///
    /// `rewind(policy:)` can be called anytime. If the sync process is in progress then it is stopped first. In this case, it make some significant
    /// time before rewind finishes. If `rewind(policy:)` is called don't call it again until publisher returned from first call finishes. Calling it
    /// again earlier results in undefined behavior.
    ///
    /// Returned publisher either completes or fails when the wipe is done. It doesn't emits any value.
    ///
    /// Possible errors:
    /// - Emits rewindErrorUnknownAnchorHeight when the rewind points to an invalid height.
    /// - Emits rewindError for other errors
    ///
    /// `rewind(policy:)` itself doesn't start the sync process when it's done and it doesn't trigger notifications as regorg would. After it is done
    /// you have start the sync process by calling `start()`
    ///
    /// If `prepare()` hasn't already been called since creating of synchronizer instance or since the last wipe then returned publisher emits
    /// `SynchronizerErrors.notPrepared` error.
    ///
    /// - Parameter policy: the rewind policy
    func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error>

    /// Wipes out internal data structures of the SDK. After this call, everything is the same as before any sync. The state of the synchronizer is
    /// switched to `unprepared`. So before the next sync, it's required to call `prepare()`.
    ///
    /// `wipe()` can be called anytime. If the sync process is in progress then it is stopped first. In this case, it make some significant time
    /// before wipe finishes. If `wipe()` is called don't call it again until publisher returned from first call finishes. Calling it again earlier
    /// results in undefined behavior.
    ///
    /// Returned publisher either completes or fails when the wipe is done. It doesn't emits any value.
    ///
    /// Majority of wipe's work is to delete files. That is only operation that can throw error during wipe. This should succeed every time. If this
    /// fails then something is seriously wrong. If the wipe fails then the SDK may be in inconsistent state. It's suggested to call wipe again until
    /// it succeed.
    ///
    /// Returned publisher emits `InitializerError.aliasAlreadyInUse` error if the Alias used to create this instance is already used by other
    /// instance.
    func wipe() -> AnyPublisher<Void, Error>
}

public enum SyncStatus: Equatable {
    /// Indicates that this Synchronizer is actively preparing to start,
    /// which usually involves setting up database tables, migrations or
    /// taking other maintenance steps that need to occur after an upgrade.
    case unprepared

    case syncing(_ progress: BlockProgress)

    /// Indicates that this Synchronizer is actively enhancing newly scanned blocks
    /// with additional transaction details, fetched from the server.
    case enhancing(_ progress: EnhancementProgress)

    /// fetches the transparent balance and stores it locally
    case fetching

    /// Indicates that this Synchronizer is fully up to date and ready for all wallet functions.
    /// When set, a UI element may want to turn green.
    case synced

    /// Indicates that [stop] has been called on this Synchronizer and it will no longer be used.
    case stopped

    /// Indicates that this Synchronizer is disconnected from its lightwalletd server.
    /// When set, a UI element may want to turn red.
    case disconnected

    case error(_ error: SynchronizerError)
    
    public var isSyncing: Bool {
        switch self {
        case .syncing, .enhancing, .fetching:
            return true
        default:
            return false
        }
    }
    
    public var isSynced: Bool {
        switch self {
        case .synced:   return true
        default:        return false
        }
    }

    public var isPrepared: Bool {
        if case .unprepared = self {
            return false
        } else {
            return true
        }
    }

    public var briefDebugDescription: String {
        switch self {
        case .unprepared: return "unprepared"
        case .syncing: return "syncing"
        case .enhancing: return "enhancing"
        case .fetching: return "fetching"
        case .synced: return "synced"
        case .stopped: return "stopped"
        case .disconnected: return "disconnected"
        case .error: return "error"
        }
    }
}

/// Kind of transactions handled by a Synchronizer
public enum TransactionKind {
    case sent
    case received
    case all
}

/// Type of rewind available
///     -birthday: rewinds the local state to this wallet's birthday
///     -height: rewinds to the nearest blockheight to the one given as argument.
///     -transaction: rewinds to the nearest height based on the anchor of the provided transaction.
public enum RewindPolicy {
    case birthday
    case height(blockheight: BlockHeight)
    case transaction(_ transaction: ZcashTransaction.Overview)
    case quick
}

extension SyncStatus {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unprepared, .unprepared): return true
        case let (.syncing(lhsProgress), .syncing(rhsProgress)): return lhsProgress == rhsProgress
        case let (.enhancing(lhsProgress), .enhancing(rhsProgress)): return lhsProgress == rhsProgress
        case (.fetching, .fetching): return true
        case (.synced, .synced): return true
        case (.stopped, .stopped): return true
        case (.disconnected, .disconnected): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

extension SyncStatus {
    init(_ blockProcessorProgress: CompactBlockProgress) {
        switch blockProcessorProgress {
        case .syncing(let progressReport):
            self = .syncing(progressReport)
        case .enhance(let enhancingReport):
            self = .enhancing(enhancingReport)
        case .fetch:
            self = .fetching
        }
    }
}
