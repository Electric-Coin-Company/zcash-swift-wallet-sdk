//
//  SDKSynchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/6/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import Combine

public extension Notification.Name {
    /// Posted when the synchronizer is started.
    /// - note: Query userInfo object for `NotificationKeys.synchronizerState`
    static let synchronizerStarted = Notification.Name("SDKSyncronizerStarted")

    /// Posted when there are progress updates.
    ///
    /// - Note: Query userInfo object for NotificationKeys.progress for Float
    /// progress percentage and NotificationKeys.blockHeight  /// for the current progress height
    static let synchronizerProgressUpdated = Notification.Name("SDKSyncronizerProgressUpdated")

    static let synchronizerStatusWillUpdate = Notification.Name("SDKSynchronizerStatusWillUpdate")

    /// Posted when the synchronizer is synced to latest height
    static let synchronizerSynced = Notification.Name("SDKSyncronizerSynced")

    /// Posted when the synchronizer is stopped
    static let synchronizerStopped = Notification.Name("SDKSyncronizerStopped")

    /// Posted when the synchronizer loses connection
    static let synchronizerDisconnected = Notification.Name("SDKSyncronizerDisconnected")

    /// Posted when the synchronizer starts syncing
    static let synchronizerSyncing = Notification.Name("SDKSynchronizerSyncing")

    /// Posted when the synchronizer starts Enhancing
    static let synchronizerEnhancing = Notification.Name("SDKSyncronizerEnhancing")

    /// Posted when the synchronizer starts fetching UTXOs
    static let synchronizerFetching = Notification.Name("SDKSyncronizerFetching")

    /// Posted when the synchronizer finds a pendingTransaction that hast been newly mined
    /// - Note: query userInfo on NotificationKeys.minedTransaction for the transaction
    static let synchronizerMinedTransaction = Notification.Name("synchronizerMinedTransaction")

    /// Posted when the synchronizer finds a mined transaction
    /// - Note: query userInfo on NotificationKeys.foundTransactions for
    /// the `[ConfirmedTransactionEntity]`. This notification could arrive in a background thread.
    static let synchronizerFoundTransactions = Notification.Name("synchronizerFoundTransactions")

    /// Notification sent when the synchronizer fetched utxos from lightwalletd attempted to store them
    /// Query the user info object for CompactBlockProcessorNotificationKey.blockProcessorStoredUTXOs which will contain a RefreshedUTXOs tuple with
    /// the collection of UTXOs stored or skipped
    static let synchronizerStoredUTXOs = Notification.Name(rawValue: "synchronizerStoredUTXOs")

    /// Posted when the synchronizer presents an error
    /// - Note: query userInfo on NotificationKeys.error for an error
    static let synchronizerFailed = Notification.Name("SDKSynchronizerFailed")

    static let synchronizerConnectionStateChanged = Notification.Name("SynchronizerConnectionStateChanged")
}

/// Synchronizer implementation for UIKit and iOS 13+
// swiftlint:disable type_body_length
public class SDKSynchronizer: Synchronizer {
    public struct SynchronizerState: Equatable {
        public var shieldedBalance: WalletBalance
        public var transparentBalance: WalletBalance
        public var syncStatus: SyncStatus
        public var latestScannedHeight: BlockHeight
    }

    public enum NotificationKeys {
        public static let progress = "SDKSynchronizer.progress"
        public static let blockHeight = "SDKSynchronizer.blockHeight"
        public static let blockDate = "SDKSynchronizer.blockDate"
        public static let minedTransaction = "SDKSynchronizer.minedTransaction"
        public static let foundTransactions = "SDKSynchronizer.foundTransactions"
        public static let error = "SDKSynchronizer.error"
        public static let currentStatus = "SDKSynchronizer.currentStatus"
        public static let nextStatus = "SDKSynchronizer.nextStatus"
        public static let currentConnectionState = "SDKSynchronizer.currentConnectionState"
        public static let previousConnectionState = "SDKSynchronizer.previousConnectionState"
        public static let synchronizerState = "SDKSynchronizer.synchronizerState"
        public static let refreshedUTXOs = "SDKSynchronizer.refreshedUTXOs"
    }

    private var underlyingStatus: SyncStatus
    public private(set) var status: SyncStatus {
        get {
            statusUpdateLock.lock()
            defer { statusUpdateLock.unlock() }
            return underlyingStatus
        }
        set {
            notifyStatusChange(newValue: newValue, oldValue: underlyingStatus)
            statusUpdateLock.lock()
            underlyingStatus = newValue
            statusUpdateLock.unlock()
            notify(status: status)
        }
    }

    let blockProcessor: CompactBlockProcessor
    let blockProcessorEventProcessingQueue = DispatchQueue(label: "blockProcessorEventProcessingQueue")

    public private(set) var progress: Float = 0.0
    public private(set) var initializer: Initializer
    public private(set) var latestScannedHeight: BlockHeight
    public private(set) var connectionState: ConnectionState
    public private(set) var network: ZcashNetwork
    public var lastState: AnyPublisher<SynchronizerState, Never> { lastStateSubject.eraseToAnyPublisher() }

    private var lastStateSubject: CurrentValueSubject<SynchronizerState, Never>
    private var transactionManager: OutboundTransactionManager
    private var transactionRepository: TransactionRepository
    private var utxoRepository: UnspentTransactionOutputRepository

    private let statusUpdateLock = NSRecursiveLock()

    private var syncStartDate: Date?

    private var longLivingCancelables: [AnyCancellable] = []
    
    /// Creates an SDKSynchronizer instance
    /// - Parameter initializer: a wallet Initializer object
    public convenience init(initializer: Initializer) throws {
        try self.init(
            status: .unprepared,
            initializer: initializer,
            transactionManager: try OutboundTransactionManagerBuilder.build(initializer: initializer),
            transactionRepository: initializer.transactionRepository,
            utxoRepository: try UTXORepositoryBuilder.build(initializer: initializer),
            blockProcessor: CompactBlockProcessor(initializer: initializer)
        )
    }

    init(
        status: SyncStatus,
        initializer: Initializer,
        transactionManager: OutboundTransactionManager,
        transactionRepository: TransactionRepository,
        utxoRepository: UnspentTransactionOutputRepository,
        blockProcessor: CompactBlockProcessor
    ) throws {
        self.connectionState = .idle
        self.underlyingStatus = status
        self.initializer = initializer
        self.transactionManager = transactionManager
        self.transactionRepository = transactionRepository
        self.utxoRepository = utxoRepository
        self.blockProcessor = blockProcessor
        let lastScannedHeight = (try? transactionRepository.lastScannedHeight()) ?? initializer.walletBirthday
        self.latestScannedHeight = lastScannedHeight
        self.network = initializer.network
        self.lastStateSubject = CurrentValueSubject(
            SynchronizerState(
                shieldedBalance: .zero,
                transparentBalance: .zero,
                syncStatus: .unprepared,
                latestScannedHeight: lastScannedHeight
            )
        )

        subscribeToProcessorNotifications(blockProcessor)

        Task(priority: .high) { [weak self] in await self?.subscribeToProcessorEvents(blockProcessor) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [blockProcessor] in
            await blockProcessor.stop()
        }
    }

    public func prepare(with seed: [UInt8]?) throws -> Initializer.InitializationResult {
        if case .seedRequired = try self.initializer.initialize(with: seed) {
            return .seedRequired
        }

        self.status = .disconnected

        return .success
    }

    /// Starts the synchronizer
    /// - Throws: CompactBlockProcessorError when failures occur
    public func start(retry: Bool = false) throws {
        switch status {
        case .unprepared:
            throw SynchronizerError.notPrepared

        case .syncing, .enhancing, .fetching:
            LoggerProxy.warn("warning: Synchronizer started when already running. Next sync process will be started when the current one stops.")
            Task {
                /// This may look strange but `CompactBlockProcessor` has mechanisms which can handle this situation. So we are fine with calling
                /// it's start here.
                await blockProcessor.start(retry: retry)
            }

        case .stopped, .synced, .disconnected, .error:
            Task {
                let state = await snapshotState()
                lastStateSubject.send(state)

                NotificationSender.default.post(
                    name: .synchronizerStarted,
                    object: self,
                    userInfo: [
                        NotificationKeys.synchronizerState: state
                    ]
                )

                syncStartDate = Date()
                await blockProcessor.start(retry: retry)
            }
        }
    }

    /// Stops the synchronizer
    public func stop() {
        guard status != .stopped, status != .disconnected else {
            LoggerProxy.info("attempted to stop when status was: \(status)")
            return
        }

        Task(priority: .high) {
            await blockProcessor.stop()
        }
    }

    private func subscribeToProcessorNotifications(_ processor: CompactBlockProcessor) {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(connectivityStateChanged(_:)),
            name: Notification.Name.synchronizerConnectionStateChanged,
            object: nil
        )
    }

    // MARK: Connectivity State

    @objc func connectivityStateChanged(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let current = userInfo[NotificationKeys.currentConnectionState] as? ConnectionState
        else {
            LoggerProxy.error(
                "Found \(notification.name) but lacks dictionary information." +
                "This is probably a programming error"
            )
            return
        }

        connectionState = current
    }

    // MARK: Handle CompactBlockProcessor.Flow

    private func subscribeToProcessorEvents(_ processor: CompactBlockProcessor) async {
        let stream = await processor.eventStream

        stream
            .receive(on: blockProcessorEventProcessingQueue)
            .sink { [weak self] event in
                switch event {
                case let .failed(error):
                    self?.failed(error: error)

                case let .finished(height, foundBlocks):
                    self?.finished(lastScannedHeight: height, foundBlocks: foundBlocks)

                case let .foundTransactions(transactions, range):
                    self?.foundTransactions(transactions: transactions, in: range)

                case let .handledReorg(reorgHeight, rewindHeight):
                    self?.handledReorg(reorgHeight: reorgHeight, rewindHeight: rewindHeight)

                case let .progressUpdated(progress):
                    self?.progressUpdated(progress: progress)

                case let .storedUTXOs(utxos):
                    self?.storedUTXOs(utxos: utxos)

                case .startedEnhancing:
                    self?.startedEnhancing()

                case .startedFetching:
                    self?.startedFetching()

                case .startedSyncing:
                    self?.startedSyncing()

                case .stopped:
                    self?.stopped()
                }
            }
            .store(in: &longLivingCancelables)
    }

    private func failed(error: CompactBlockProcessorError) {
        self.notifyFailure(error)
        self.status = .error(self.mapError(error))
    }

    private func finished(lastScannedHeight: BlockHeight, foundBlocks: Bool) {
        // FIX: Pending transaction updates fail if done from another thread. Improvement needed: explicitly define queues for sql repositories see: https://github.com/zcash/ZcashLightClientKit/issues/450
        self.latestScannedHeight = lastScannedHeight
        self.refreshPendingTransactions()
        self.status = .synced

        if let syncStartDate {
            SDKMetrics.shared.pushSyncReport(
                start: syncStartDate,
                end: Date()
            )
        }
    }

    private func foundTransactions(transactions: [ZcashTransaction.Overview], in range: CompactBlockRange) {
        NotificationSender.default.post(
            name: .synchronizerFoundTransactions,
            object: self,
            userInfo: [
                NotificationKeys.foundTransactions: transactions
            ]
        )
    }

    private func handledReorg(reorgHeight: BlockHeight, rewindHeight: BlockHeight) {
        LoggerProxy.debug("handling reorg at: \(reorgHeight) with rewind height: \(rewindHeight)")

        do {
            try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            LoggerProxy.debug("error handling reorg: \(error)")
            notifyFailure(error)
        }
    }

    private func progressUpdated(progress: CompactBlockProgress) {
        self.notify(progress: progress)
    }

    private func storedUTXOs(utxos: (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])) {
        NotificationSender.default.post(
            name: .synchronizerStoredUTXOs,
            object: self,
            userInfo: [NotificationKeys.refreshedUTXOs: utxos]
        )
    }

    private func startedEnhancing() {
        statusUpdateLock.lock()
        defer { statusUpdateLock.unlock() }

        guard status != .enhancing(NullEnhancementProgress()) else { return }
        status = .enhancing(NullEnhancementProgress())
    }

    private func startedFetching() {
        statusUpdateLock.lock()
        defer { statusUpdateLock.unlock() }

        guard status != .fetching else { return }
        status = .fetching
    }

    private func startedSyncing() {
        statusUpdateLock.lock()
        defer { statusUpdateLock.unlock() }

        guard status != .syncing(.nullProgress) else { return }
        status = .syncing(.nullProgress)
    }

    private func stopped() {
        statusUpdateLock.lock()
        defer { statusUpdateLock.unlock() }

        guard status != .stopped else { return }
        status = .stopped
    }

    // MARK: Synchronizer methods

    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) async throws -> PendingTransactionEntity {
        do {
            try await SaplingParameterDownloader.downloadParamsIfnotPresent(
                spendURL: initializer.spendParamsURL,
                outputURL: initializer.outputParamsURL
            )
        } catch {
            throw SynchronizerError.parameterMissing(underlyingError: error)
        }

        if case Recipient.transparent = toAddress, memo != nil {
            throw SynchronizerError.generalError(message: "Memos can't be sent to transparent addresses.")
        }

        return try await createToAddress(
            spendingKey: spendingKey,
            zatoshi: zatoshi,
            recipient: toAddress,
            memo: memo
        )
    }

    public func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) async throws -> PendingTransactionEntity {
        // let's see if there are funds to shield
        let accountIndex = Int(spendingKey.account)
        do {
            let tBalance = try await self.getTransparentBalance(accountIndex: accountIndex)

            // Verify that at least there are funds for the fee. Ideally this logic will be improved by the shielding   wallet.
            guard tBalance.verified >= self.network.constants.defaultFee(for: self.latestScannedHeight) else {
                throw ShieldFundsError.insuficientTransparentFunds
            }

            let shieldingSpend = try transactionManager.initSpend(
                zatoshi: tBalance.verified,
                recipient: .internalAccount(spendingKey.account),
                memo: try memo.asMemoBytes(),
                from: accountIndex
            )

            // TODO: [#487] Task will be removed when this method is changed to async, issue 487, https://github.com/zcash/ZcashLightClientKit/issues/487
            let transaction = try await transactionManager.encodeShieldingTransaction(
                spendingKey: spendingKey,
                shieldingThreshold: shieldingThreshold,
                pendingTransaction: shieldingSpend
            )

            return try await transactionManager.submit(pendingTransaction: transaction)
        } catch {
            throw error
        }
    }

    func createToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        recipient: Recipient,
        memo: Memo?
    ) async throws -> PendingTransactionEntity {
        do {
            let spend = try transactionManager.initSpend(
                zatoshi: zatoshi,
                recipient: .address(recipient),
                memo: memo?.asMemoBytes(),
                from: Int(spendingKey.account)
            )

            let transaction = try await transactionManager.encode(
                spendingKey: spendingKey,
                pendingTransaction: spend
            )
            let submittedTx = try await transactionManager.submit(pendingTransaction: transaction)
            return submittedTx
        } catch {
            throw error
        }
    }

    public func cancelSpend(transaction: PendingTransactionEntity) -> Bool {
        transactionManager.cancel(pendingTransaction: transaction)
    }

    public func allReceivedTransactions() throws -> [ZcashTransaction.Received] {
        try transactionRepository.findReceived(offset: 0, limit: Int.max)
    }

    public func allPendingTransactions() throws -> [PendingTransactionEntity] {
        try transactionManager.allPendingTransactions() ?? [PendingTransactionEntity]()
    }

    public func allClearedTransactions() throws -> [ZcashTransaction.Overview] {
        return try transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
    }

    public func allSentTransactions() throws -> [ZcashTransaction.Sent] {
        return try transactionRepository.findSent(offset: 0, limit: Int.max)
    }

    public func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) throws -> [ZcashTransaction.Overview] {
        return try transactionRepository.find(from: transaction, limit: limit, kind: .all)
    }

    public func paginatedTransactions(of kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        PagedTransactionRepositoryBuilder.build(initializer: initializer, kind: .all)
    }

    public func getMemos(for transaction: ZcashTransaction.Overview) throws -> [Memo] {
        return try transactionRepository.findMemos(for: transaction)
    }

    public func getMemos(for receivedTransaction: ZcashTransaction.Received) throws -> [Memo] {
        return try transactionRepository.findMemos(for: receivedTransaction)
    }

    public func getMemos(for sentTransaction: ZcashTransaction.Sent) throws -> [Memo] {
        return try transactionRepository.findMemos(for: sentTransaction)
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview) -> [TransactionRecipient] {
        return transactionRepository.getRecipients(for: transaction.id)
    }

    public func getRecipients(for transaction: ZcashTransaction.Sent) -> [TransactionRecipient] {
        return transactionRepository.getRecipients(for: transaction.id)
    }

    public func latestHeight(result: @escaping (Result<BlockHeight, Error>) -> Void) {
        Task {
            do {
                let latestBlockHeight = try await blockProcessor.blockDownloaderService.latestBlockHeightAsync()
                result(.success(latestBlockHeight))
            } catch {
                result(.failure(error))
            }
        }
    }

    public func latestHeight() async throws -> BlockHeight {
        try await blockProcessor.blockDownloaderService.latestBlockHeightAsync()
    }

    public func latestUTXOs(address: String) async throws -> [UnspentTransactionOutputEntity] {
        guard initializer.isValidTransparentAddress(address) else {
            throw SynchronizerError.generalError(message: "invalid t-address")
        }
        
        let stream = initializer.lightWalletService.fetchUTXOs(for: address, height: network.constants.saplingActivationHeight)
        
        do {
            // swiftlint:disable:next array_constructor
            var utxos: [UnspentTransactionOutputEntity] = []
            for try await transactionEntity in stream {
                utxos.append(transactionEntity)
            }
            try self.utxoRepository.clearAll(address: address)
            try self.utxoRepository.store(utxos: utxos)
            return utxos
        } catch {
            throw SynchronizerError.generalError(message: "\(error)")
        }
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        try await blockProcessor.refreshUTXOs(tAddress: address, startHeight: height)
    }
    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    public func getShieldedBalance(accountIndex: Int = 0) -> Int64 {
        initializer.getBalance(account: accountIndex).amount
    }

    public func getShieldedBalance(accountIndex: Int = 0) -> Zatoshi {
        initializer.getBalance(account: accountIndex)
    }

    @available(*, deprecated, message: "This function will be removed soon, use the one returning a `Zatoshi` value instead")
    public func getShieldedVerifiedBalance(accountIndex: Int = 0) -> Int64 {
        initializer.getVerifiedBalance(account: accountIndex).amount
    }

    public func getShieldedVerifiedBalance(accountIndex: Int = 0) -> Zatoshi {
        initializer.getVerifiedBalance(account: accountIndex)
    }

    public func getSaplingAddress(accountIndex: Int) async -> SaplingAddress? {
        await blockProcessor.getSaplingAddress(accountIndex: accountIndex)
    }

    public func getUnifiedAddress(accountIndex: Int) async -> UnifiedAddress? {
        await blockProcessor.getUnifiedAddress(accountIndex: accountIndex)
    }

    public func getTransparentAddress(accountIndex: Int) async -> TransparentAddress? {
        await blockProcessor.getTransparentAddress(accountIndex: accountIndex)
    }

    /// Returns the last stored transparent balance
    public func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance {
        try await blockProcessor.getTransparentBalance(accountIndex: accountIndex)
    }

    public func rewind(_ policy: RewindPolicy) async throws {
        self.stop()

        var height: BlockHeight?

        switch policy {
        case .quick:
            break

        case .birthday:
            let birthday = await self.blockProcessor.config.walletBirthday
            height = birthday

        case .height(let rewindHeight):
            height = rewindHeight

        case .transaction(let transaction):
            guard let txHeight = transaction.anchor(network: self.network) else {
                throw SynchronizerError.rewindErrorUnknownArchorHeight
            }
            height = txHeight
        }

        do {
            let rewindHeight = try await self.blockProcessor.rewindTo(height)
            try self.transactionManager.handleReorg(at: rewindHeight)
        } catch {
            throw SynchronizerError.rewindError(underlyingError: error)
        }
    }

    public func wipe() async throws {
        do {
            try await blockProcessor.wipe()
        } catch {
            throw SynchronizerError.wipeAttemptWhileProcessing
        }

        transactionManager.closeDBConnection()
        transactionRepository.closeDBConnection()

        try? FileManager.default.removeItem(at: initializer.fsBlockDbRoot)
        try? FileManager.default.removeItem(at: initializer.pendingDbURL)
        try? FileManager.default.removeItem(at: initializer.dataDbURL)

        status = .unprepared
    }

    // MARK: notify state
    private func notify(progress: CompactBlockProgress) {
        var userInfo: [AnyHashable: Any] = .init()
        userInfo[NotificationKeys.progress] = progress
        userInfo[NotificationKeys.blockHeight] = progress.progressHeight

        self.status = SyncStatus(progress)
        NotificationSender.default.post(name: Notification.Name.synchronizerProgressUpdated, object: self, userInfo: userInfo)
    }

    private func notifyStatusChange(newValue: SyncStatus, oldValue: SyncStatus) {
        NotificationSender.default.post(
            name: .synchronizerStatusWillUpdate,
            object: self,
            userInfo:
                [
                    NotificationKeys.currentStatus: oldValue,
                    NotificationKeys.nextStatus: newValue
                ]
        )
    }

    private func snapshotState() async -> SDKSynchronizer.SynchronizerState {
        SynchronizerState(
            shieldedBalance: WalletBalance(
                verified: initializer.getVerifiedBalance(),
                total: initializer.getBalance()
            ),
            transparentBalance: (try? await blockProcessor.getTransparentBalance(accountIndex: 0)) ?? .zero,
            syncStatus: status,
            latestScannedHeight: self.latestScannedHeight
        )
    }

    private func notify(status: SyncStatus) {
        switch status {
        case .disconnected:
            NotificationSender.default.post(name: Notification.Name.synchronizerDisconnected, object: self)
        case .stopped:
            NotificationSender.default.post(name: Notification.Name.synchronizerStopped, object: self)
        case .synced:
            Task {
                let state = await self.snapshotState()
                self.lastStateSubject.send(state)

                NotificationSender.default.post(
                    name: Notification.Name.synchronizerSynced,
                    object: self,
                    userInfo: [
                        SDKSynchronizer.NotificationKeys.blockHeight: self.latestScannedHeight,
                        SDKSynchronizer.NotificationKeys.synchronizerState: state
                    ]
                )
            }
        case .unprepared:
            break
        case .syncing:
            NotificationSender.default.post(name: Notification.Name.synchronizerSyncing, object: self)
        case .enhancing:
            NotificationSender.default.post(name: Notification.Name.synchronizerEnhancing, object: self)
        case .fetching:
            NotificationSender.default.post(name: Notification.Name.synchronizerFetching, object: self)
        case .error(let error):
            self.notifyFailure(error)
        }
    }
    // MARK: book keeping

    private func updateMinedTransactions() throws {
        try transactionManager.allPendingTransactions()?
            .filter { $0.isSubmitSuccess && !$0.isMined }
            .forEach { pendingTx in
                guard let rawID = pendingTx.rawTransactionId else { return }
                let transaction = try transactionRepository.find(rawID: rawID)
                guard let minedHeight = transaction.minedHeight else { return }

                let minedTx = try transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)

                notifyMinedTransaction(minedTx)
            }
    }

    private func removeConfirmedTransactions() throws {
        let latestHeight = try transactionRepository.lastScannedHeight()

        try transactionManager.allPendingTransactions()?
            .filter { $0.minedHeight > 0 && abs($0.minedHeight - latestHeight) >= ZcashSDK.defaultStaleTolerance }
            .forEach { try transactionManager.delete(pendingTransaction: $0) }
    }

    private func refreshPendingTransactions() {
        do {
            try updateMinedTransactions()
            try removeConfirmedTransactions()
        } catch {
            LoggerProxy.debug("error refreshing pending transactions: \(error)")
        }
    }

    private func notifyMinedTransaction(_ transaction: PendingTransactionEntity) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NotificationSender.default.post(
                name: Notification.Name.synchronizerMinedTransaction,
                object: self,
                userInfo: [NotificationKeys.minedTransaction: transaction]
            )
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func mapError(_ error: Error) -> Error {
        if let compactBlockProcessorError = error as? CompactBlockProcessorError {
            switch compactBlockProcessorError {
            case .dataDbInitFailed(let path):
                return SynchronizerError.initFailed(message: "DataDb init failed at path: \(path)")
            case .connectionError(let message):
                return SynchronizerError.connectionFailed(message: message)
            case .invalidConfiguration:
                return SynchronizerError.generalError(message: "Invalid Configuration")
            case .missingDbPath(let path):
                return SynchronizerError.initFailed(message: "missing Db path: \(path)")
            case .generalError(let message):
                return SynchronizerError.generalError(message: message)
            case .maxAttemptsReached(attempts: let attempts):
                return SynchronizerError.maxRetryAttemptsReached(attempts: attempts)
            case let .grpcError(statusCode, message):
                return SynchronizerError.connectionError(status: statusCode, message: message)
            case .connectionTimeout:
                return SynchronizerError.networkTimeout
            case .unspecifiedError(let underlyingError):
                return SynchronizerError.uncategorized(underlyingError: underlyingError)
            case .criticalError:
                return SynchronizerError.criticalError
            case .invalidAccount:
                return SynchronizerError.invalidAccount
            case .wrongConsensusBranchId:
                return SynchronizerError.lightwalletdValidationFailed(underlyingError: compactBlockProcessorError)
            case .networkMismatch:
                return SynchronizerError.lightwalletdValidationFailed(underlyingError: compactBlockProcessorError)
            case .rewindAttemptWhileProcessing:
                break
            case .saplingActivationMismatch:
                return SynchronizerError.lightwalletdValidationFailed(underlyingError: compactBlockProcessorError)
            case .unknown:
                break
            case .wipeAttemptWhileProcessing:
                break
            }
        }

        return SynchronizerError.uncategorized(underlyingError: error)
    }

    private func notifyFailure(_ error: Error) {
        NotificationSender.default.post(
            name: Notification.Name.synchronizerFailed,
            object: self,
            userInfo: [NotificationKeys.error: self.mapError(error)]
        )
    }
}

extension SDKSynchronizer {
    public var pendingTransactions: [PendingTransactionEntity] {
        (try? self.allPendingTransactions()) ?? [PendingTransactionEntity]()
    }

    public var clearedTransactions: [ZcashTransaction.Overview] {
        (try? self.allClearedTransactions()) ?? []
    }

    public var sentTransactions: [ZcashTransaction.Sent] {
        (try? self.allSentTransactions()) ?? []
    }

    public var receivedTransactions: [ZcashTransaction.Received] {
        (try? self.allReceivedTransactions()) ?? []
    }
}

extension SDKSynchronizer {
    public func getUnifiedAddress(accountIndex: Int) -> UnifiedAddress? {
        self.initializer.getCurrentAddress(accountIndex: accountIndex)
    }

    public func getSaplingAddress(accountIndex: Int) -> SaplingAddress? {
        self.getUnifiedAddress(accountIndex: accountIndex)?.saplingReceiver()
    }

    public func getTransparentAddress(accountIndex: Int) -> TransparentAddress? {
        self.getUnifiedAddress(accountIndex: accountIndex)?.transparentReceiver()
    }
}

private struct NullEnhancementProgress: EnhancementProgress {
    var totalTransactions: Int { 0 }
    var enhancedTransactions: Int { 0 }
    var lastFoundTransaction: ZcashTransaction.Overview? { nil }
    var range: CompactBlockRange { 0 ... 0 }
}
