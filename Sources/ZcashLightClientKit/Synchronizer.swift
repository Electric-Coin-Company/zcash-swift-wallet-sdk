//
//  Synchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/5/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import Foundation

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

/// Reports the state of a synchronizer.
public struct SynchronizerState: Equatable {
    /// Unique Identifier for the current sync attempt
    /// - Note: Although on it's lifetime a synchronizer will attempt to sync between random fractions of a minute (when idle),
    /// each sync attempt will be considered a new sync session. This is to maintain a consistent UUID cadence
    /// given how application lifecycle varies between OS Versions, platforms, etc.
    /// SyncSessionIDs are provided to users
    public var syncSessionID: UUID
    /// shielded balance known to this synchronizer given the data that has processed locally
    public var shieldedBalance: WalletBalance
    /// transparent balance known to this synchronizer given the data that has processed locally
    public var transparentBalance: WalletBalance
    /// status of the whole sync process
    var internalSyncStatus: InternalSyncStatus
    public var syncStatus: SyncStatus
    /// height of the latest scanned block known to this synchronizer.
    public var latestScannedHeight: BlockHeight
    /// height of the latest block on the blockchain known to this synchronizer.
    public var latestBlockHeight: BlockHeight
    /// timestamp of the latest scanned block on the blockchain known to this synchronizer.
    /// The anchor point is timeIntervalSince1970
    public var latestScannedTime: TimeInterval

    /// Represents a synchronizer that has made zero progress hasn't done a sync attempt
    public static var zero: SynchronizerState {
        SynchronizerState(
            syncSessionID: .nullID,
            shieldedBalance: .zero,
            transparentBalance: .zero,
            internalSyncStatus: .unprepared,
            latestScannedHeight: .zero,
            latestBlockHeight: .zero,
            latestScannedTime: 0
        )
    }
    
    init(
        syncSessionID: UUID,
        shieldedBalance: WalletBalance,
        transparentBalance: WalletBalance,
        internalSyncStatus: InternalSyncStatus,
        latestScannedHeight: BlockHeight,
        latestBlockHeight: BlockHeight,
        latestScannedTime: TimeInterval
    ) {
        self.syncSessionID = syncSessionID
        self.shieldedBalance = shieldedBalance
        self.transparentBalance = transparentBalance
        self.internalSyncStatus = internalSyncStatus
        self.latestScannedHeight = latestScannedHeight
        self.latestBlockHeight = latestBlockHeight
        self.latestScannedTime = latestScannedTime
        self.syncStatus = internalSyncStatus.mapToSyncStatus()
    }
}

public enum SynchronizerEvent {
    // Sent when the synchronizer finds a pendingTransaction that has been newly mined.
    case minedTransaction(ZcashTransaction.Overview)

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
    /// Alias used for this instance.
    var alias: ZcashSynchronizerAlias { get }

    /// Latest state of the SDK which can be get in synchronous manner.
    var latestState: SynchronizerState { get }

    /// reflects current connection state to LightwalletEndpoint
    var connectionState: ConnectionState { get }

    /// This stream is backed by `CurrentValueSubject`. This is primary source of information about what is the SDK doing. New values are emitted when
    /// `InternalSyncStatus` is changed inside the SDK.
    ///
    /// Synchronization progress is part of the `InternalSyncStatus` so this stream emits lot of values. `throttle` can be used to control amout of values
    /// delivered. Values are delivered on random background thread.
    var stateStream: AnyPublisher<SynchronizerState, Never> { get }

    /// This stream is backed by `PassthroughSubject`. Check `SynchronizerEvent` to see which events may be emitted.
    var eventStream: AnyPublisher<SynchronizerEvent, Never> { get }

    /// An object that when enabled collects mertrics from the synchronizer
    var metrics: SDKMetrics { get }
    
    /// Default algorithm used to sync the stored wallet with the blockchain.
    var syncAlgorithm: SyncAlgorithm { get }

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
    ///   - seed: ZIP-32 Seed bytes for the wallet that will be initialized
    ///   - walletBirthday: Birthday of wallet.
    /// - Throws:
    ///     - `aliasAlreadyInUse` if the Alias used to create this instance is already used by other instance.
    ///     - `cantUpdateURLWithAlias` if the updating of paths in `Initilizer` according to alias fails. When this happens it means that
    ///                                some path passed to `Initializer` is invalid. The SDK can't recover from this and this instance
    ///                                won't do anything.
    ///     - Some other `ZcashError` thrown by lower layer of the SDK.
    func prepare(
        with seed: [UInt8]?,
        walletBirthday: BlockHeight
    ) async throws -> Initializer.InitializationResult

    /// Starts this synchronizer within the given scope.
    ///
    /// Implementations should leverage structured concurrency and
    /// cancel all jobs when this scope completes.
    func start(retry: Bool) async throws

    /// Stop this synchronizer. Implementations should ensure that calling this method cancels all jobs that were created by this instance.
    /// It make some time before the SDK stops any activity. It doesn't have to be stopped when this function finishes.
    /// Observe `stateStream` or `latestState` to recognize that the SDK stopped any activity.
    func stop()

    /// Gets the sapling shielded address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getSaplingAddress(accountIndex: Int) async throws -> SaplingAddress

    /// Gets the unified address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getUnifiedAddress(accountIndex: Int) async throws -> UnifiedAddress

    /// Gets the transparent address for the given account.
    /// - Parameter accountIndex: the optional accountId whose address is of interest. By default, the first account is used.
    /// - Returns the address or nil if account index is incorrect
    func getTransparentAddress(accountIndex: Int) async throws -> TransparentAddress
    
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
    ) async throws -> ZcashTransaction.Overview

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
    ) async throws -> ZcashTransaction.Overview

    /// all outbound pending transactions that have been sent but are awaiting confirmations
    var pendingTransactions: [ZcashTransaction.Overview] { get async }

    /// all the transactions that are on the blockchain
    var transactions: [ZcashTransaction.Overview] { get async }

    /// All transactions that are related to sending funds
    var sentTransactions: [ZcashTransaction.Overview] { get async }

    /// all transactions related to receiving funds
    var receivedTransactions: [ZcashTransaction.Overview] { get async }
    
    /// A repository serving transactions in a paginated manner
    /// - Parameter kind: Transaction Kind expected from this PaginatedTransactionRepository
    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository

    /// Get all memos for `transaction`.
    ///
    // sourcery: mockedName="getMemosForClearedTransaction"
    func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo]

    /// Attempt to get recipients from a Transaction Overview.
    /// - parameter transaction: A transaction overview
    /// - returns the recipients or an empty array if no recipients are found on this transaction because it's not an outgoing
    /// transaction
    ///
    // sourcery: mockedName="getRecipientsForClearedTransaction"
    func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient]

    /// Attempt to get outputs involved in a given Transaction.
    /// - parameter transaction: A transaction overview
    /// - returns the array of outputs involved in this transaction. Transparent outputs might not be tracked 
    ///
    // sourcery: mockedName="getTransactionOutputsForTransaction"
    func getTransactionOutputs(for transaction: ZcashTransaction.Overview) async -> [ZcashTransaction.Output]

    /// Returns a list of confirmed transactions that preceed the given transaction with a limit count.
    /// - Parameters:
    ///     - from: the confirmed transaction from which the query should start from or nil to retrieve from the most recent transaction
    ///     - limit: the maximum amount of items this should return if available
    /// - Returns: an array with the given Transactions or an empty array
    func allTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview]

    /// Fetch all pending transactions
    /// - Returns: an array of transactions which are considered pending confirmation. can be empty
    func allPendingTransactions() async throws -> [ZcashTransaction.Overview]

    /// Returns the latest block height from the provided Lightwallet endpoint
    func latestHeight() async throws -> BlockHeight

    /// Returns the latests UTXOs for the given address from the specified height on
    ///
    /// If `prepare()` hasn't already been called since creating of synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs

    /// Returns the last stored transparent balance
    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance

    /// get (unverified) balance from the given account index
    /// - Parameter accountIndex: the index of the account
    /// - Returns: balance in `Zatoshi`
    func getShieldedBalance(accountIndex: Int) async throws -> Zatoshi

    /// get verified balance from the given account index
    /// - Parameter accountIndex: the index of the account
    /// - Returns: balance in `Zatoshi`
    func getShieldedVerifiedBalance(accountIndex: Int) async throws -> Zatoshi

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
    /// Returned publisher emits `initializerCantUpdateURLWithAlias` error if the Alias used to create this instance is already used by other
    /// instance.
    ///
    /// Returned publisher emits `initializerAliasAlreadyInUse` if the updating of paths in `Initilizer` according to alias fails. When
    /// this happens it means that some path passed to `Initializer` is invalid. The SDK can't recover from this and this instance won't do anything.
    /// 
    func wipe() -> AnyPublisher<Void, Error>
}

public enum SyncStatus: Equatable {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unprepared, .unprepared): return true
        case let (.syncing(lhsProgress), .syncing(rhsProgress)): return lhsProgress == rhsProgress
        case (.upToDate, .upToDate): return true
        case (.error, .error): return true
        default: return false
        }
    }
    
    /// Indicates that this Synchronizer is actively preparing to start,
    /// which usually involves setting up database tables, migrations or
    /// taking other maintenance steps that need to occur after an upgrade.
    case unprepared

    case syncing(_ progress: Float)

    /// Indicates that this Synchronizer is fully up to date and ready for all wallet functions.
    /// When set, a UI element may want to turn green.
    case upToDate

    case error(_ error: Error)
    
    public var isSyncing: Bool {
        if case .syncing = self {
            return true
        }
        
        return false
    }
    
    public var isSynced: Bool {
        if case .upToDate = self {
            return true
        }
        
        return false
    }

    public var isPrepared: Bool {
        if case .unprepared = self {
            return false
        }
        
        return true
    }

    public var briefDebugDescription: String {
        switch self {
        case .unprepared: return "unprepared"
        case .syncing: return "syncing"
        case .upToDate: return "up to date"
        case .error: return "error"
        }
    }
}

enum InternalSyncStatus: Equatable {
    /// Indicates that this Synchronizer is actively preparing to start,
    /// which usually involves setting up database tables, migrations or
    /// taking other maintenance steps that need to occur after an upgrade.
    case unprepared

    /// Indicates that this Synchronizer is actively processing new blocks (consists of fetch, scan and enhance operations)
    case syncing(Float)
    
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
        if case .syncing = self {
            return true
        }
        
        return false
    }
    
    public var isSynced: Bool {
        if case .synced = self {
            return true
        }
        
        return false
    }

    public var isPrepared: Bool {
        if case .unprepared = self {
            return false
        }
        
        return true
    }

    public var briefDebugDescription: String {
        switch self {
        case .unprepared: return "unprepared"
        case .syncing: return "syncing"
        case .synced: return "synced"
        case .stopped: return "stopped"
        case .disconnected: return "disconnected"
        case .error: return "error"
        }
    }
}

/// Algorithm used to sync the sdk with the blockchain
public enum SyncAlgorithm: Equatable {
    /// Linear sync processes the unsynced blocks in a linear way up to the chain tip
    case linear
    /// Spend before Sync processes the unsynced blocks non-lineary, in prioritised ranges relevant to the stored wallet.
    /// Note: This feature is in development (alpha version) so use carefully.
    case spendBeforeSync
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

extension InternalSyncStatus {
    public static func == (lhs: InternalSyncStatus, rhs: InternalSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unprepared, .unprepared): return true
        case let (.syncing(lhsProgress), .syncing(rhsProgress)): return lhsProgress == rhsProgress
        case (.synced, .synced): return true
        case (.stopped, .stopped): return true
        case (.disconnected, .disconnected): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

extension InternalSyncStatus {
    init(_ blockProcessorProgress: Float) {
        self = .syncing(blockProcessorProgress)
    }
}

extension InternalSyncStatus {
    func mapToSyncStatus() -> SyncStatus {
        switch self {
        case .unprepared:
            return .unprepared
        case .syncing(let progress):
            return .syncing(progress)
        case .synced:
            return .upToDate
        case .stopped:
            return .upToDate
        case .disconnected:
            return .error(ZcashError.synchronizerDisconnected)
        case .error(let error):
            return .error(error)
        }
    }
}

extension UUID {
    /// UUID  00000000-0000-0000-0000-000000000000
    static var nullID: UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
}
