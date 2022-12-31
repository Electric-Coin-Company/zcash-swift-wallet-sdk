//
//  Synchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/5/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

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


/// Primary interface for interacting with the SDK. Defines the contract that specific
/// implementations like SdkSynchronizer fulfill.
public protocol Synchronizer {

    /// Value representing the Status of this Synchronizer. As the status changes, it will be also notified
    var status: SyncStatus { get }

    /// reflects current connection state to LightwalletEndpoint
    var connectionState: ConnectionState { get }

    /// prepares this initializer to operate. Initializes the internal state with the given
    /// Extended Viewing Keys and a wallet birthday found in the initializer object
    func prepare(with seed: [UInt8]?) async throws -> Initializer.InitializationResult

    ///Starts this synchronizer within the given scope.
    ///
    ///Implementations should leverage structured concurrency and
    ///cancel all jobs when this scope completes.
    func start(retry: Bool) throws

    /// Stop this synchronizer. Implementations should ensure that calling this method cancels all jobs that were created by this instance.
    func stop() throws

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
    // swiftlint:disable:next function_parameter_count
    func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) async throws -> PendingTransactionEntity

    /// Shields transparent funds from the given private key into the best shielded pool of the account associated to the given `UnifiedSpendingKey`.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` that allows to spend transparent funds
    /// - Parameter memo: the optional memo to include as part of the transaction.
    func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo
    ) async throws -> PendingTransactionEntity

    /// Attempts to cancel a transaction that is about to be sent. Typically, cancellation is only
    /// an option if the transaction has not yet been submitted to the server.
    /// - Parameter transaction: the transaction to cancel.
    /// - Returns: true when the cancellation request was successful. False when it is too late.
    func cancelSpend(transaction: PendingTransactionEntity) -> Bool

    /// all outbound pending transactions that have been sent but are awaiting confirmations
    var pendingTransactions: [PendingTransactionEntity] { get }

    /// all the transactions that are on the blockchain
    var clearedTransactions: [ConfirmedTransactionEntity] { get }

    /// All transactions that are related to sending funds
    var sentTransactions: [ConfirmedTransactionEntity] { get }

    /// all transactions related to receiving funds
    var receivedTransactions: [ConfirmedTransactionEntity] { get }
    
    /// A repository serving transactions in a paginated manner
    /// - Parameter kind: Transaction Kind expected from this PaginatedTransactionRepository
    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository

    /// Returns a list of confirmed transactions that precede the given transaction with a limit count.
    /// - Parameters:
    ///     - from: the confirmed transaction from which the query should start from or nil to retrieve from the most recent transaction
    ///     - limit: the maximum amount of items this should return if available
    ///     - Returns: an array with the given Transactions or nil
    func allConfirmedTransactions(from transaction: ConfirmedTransactionEntity?, limit: Int) throws -> [ConfirmedTransactionEntity]?    

    /// Returns the latest block height from the provided Lightwallet endpoint
    func latestHeight(result: @escaping (Result<BlockHeight, Error>) -> Void)

    /// Returns the latest block height from the provided Lightwallet endpoint
    /// Blocking
    func latestHeight() async throws -> BlockHeight
    

    /// Returns the latests UTXOs for the given address from the specified height on
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


    /// Rescans the known blocks with the current keys. If this is called while sync process is in progress then
    /// `SynchronizerError.rewindError(CompactBlockProcessorError.rewindAttemptWhileProcessing)` is thrown.
    ///
    /// - Parameter policy: the rewind policy
    /// - Throws rewindErrorUnknownAnchorHeight when the rewind points to an invalid height
    /// - Throws rewindError for other errors
    /// - Note rewind does not trigger notifications as a reorg would. You need to restart the synchronizer afterwards
    func rewind(_ policy: RewindPolicy) async throws
}

public enum SyncStatus: Equatable {

    /// Indicates that this Synchronizer is actively preparing to start,
    /// which usually involves setting up database tables, migrations or
    /// taking other maintenance steps that need to occur after an upgrade.
    case unprepared

    /// Indicates that this Synchronizer is actively downloading new blocks from the server.
    case downloading(_ status: BlockProgress)

    /// Indicates that this Synchronizer is actively validating new blocks that were downloaded
    /// from the server. Blocks need to be verified before they are scanned. This confirms that
    /// each block is chain-sequential, thereby detecting missing blocks and reorgs.
    case validating

    /// Indicates that this Synchronizer is actively scanning new valid blocks that were
    /// downloaded from the server.
    case scanning(_ progress: BlockProgress)

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

    case error(_ error: Error)
    
    public var isSyncing: Bool {
        switch self {
        case .downloading, .validating, .scanning, .enhancing, .fetching:
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
    case transaction(_ transaction: TransactionEntity)
    case quick
}

extension SyncStatus {
    // swiftlint:disable cyclomatic_complexity
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch lhs {
        case .unprepared:
            if case .unprepared = rhs {
                return true
            } else {
                return false
            }
        case .disconnected:
            if case .disconnected = rhs {
                return true
            } else {
                return false
            }
        case .downloading:
            if case .downloading = rhs {
                return true
            } else {
                return false
            }
        case .validating:
            if case .validating = rhs {
                return true
            } else {
                return false
            }
        case .scanning:
            if case .scanning = rhs {
                return true
            } else {
                return false
            }
        case .enhancing:
            if case .enhancing = rhs {
                return true
            } else {
                return false
            }
        case .fetching:
            if case .fetching = rhs {
                return true
            } else {
                return false
            }
        case .synced:
            if case .synced = rhs {
                return true
            } else {
                return false
            }
        case .stopped:
            if case .stopped = rhs {
                return true
            } else {
                return false
            }
        case .error:
            if case .error = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

extension SyncStatus {
    init(_ blockProcessorProgress: CompactBlockProgress) {
        switch blockProcessorProgress {
        case .download(let progressReport):
            self = SyncStatus.downloading(progressReport)
        case .validate:
            self = .validating
        case .scan(let progressReport):
            self = .scanning(progressReport)
        case .enhance(let enhancingReport):
            self = .enhancing(enhancingReport)
        case .fetch:
            self = .fetching
        }
    }
}
