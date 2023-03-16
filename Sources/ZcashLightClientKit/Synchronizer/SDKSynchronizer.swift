//
//  SDKSynchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/6/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import Combine

extension Notification.Name {
    static let synchronizerConnectionStateChanged = Notification.Name("SynchronizerConnectionStateChanged")
}

/// Synchronizer implementation for UIKit and iOS 13+
// swiftlint:disable type_body_length
public class SDKSynchronizer: Synchronizer {
    public enum NotificationKeys {
        public static let currentConnectionState = "SDKSynchronizer.currentConnectionState"
        public static let previousConnectionState = "SDKSynchronizer.previousConnectionState"
    }

    private let streamsUpdateQueue = DispatchQueue(label: "streamsUpdateQueue")
    private let stateSubject = CurrentValueSubject<SynchronizerState, Never>(.zero)
    public var stateStream: AnyPublisher<SynchronizerState, Never> { stateSubject.eraseToAnyPublisher() }
    public private(set) var latestState: SynchronizerState = .zero

    private let eventSubject = PassthroughSubject<SynchronizerEvent, Never>()
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { eventSubject.eraseToAnyPublisher() }

    private let statusUpdateLock = NSRecursiveLock()
    private var underlyingStatus: SyncStatus
    var status: SyncStatus {
        get {
            statusUpdateLock.lock()
            defer { statusUpdateLock.unlock() }
            return underlyingStatus
        }
        set {
            statusUpdateLock.lock()
            let oldValue = underlyingStatus
            underlyingStatus = newValue
            notify(oldStatus: oldValue, newStatus: newValue)
            statusUpdateLock.unlock()
        }
    }

    let blockProcessor: CompactBlockProcessor
    let blockProcessorEventProcessingQueue = DispatchQueue(label: "blockProcessorEventProcessingQueue")

    public private(set) var initializer: Initializer
    // Valid value is stored here after `prepare` is called.
    public private(set) var latestScannedHeight: BlockHeight = .zero
    public private(set) var connectionState: ConnectionState
    public private(set) var network: ZcashNetwork
    private var transactionManager: OutboundTransactionManager
    private var transactionRepository: TransactionRepository
    private var utxoRepository: UnspentTransactionOutputRepository

    private var syncStartDate: Date?

    private var longLivingCancelables: [AnyCancellable] = []
    
    /// Creates an SDKSynchronizer instance
    /// - Parameter initializer: a wallet Initializer object
    public convenience init(initializer: Initializer) {
        self.init(
            status: .unprepared,
            initializer: initializer,
            transactionManager: OutboundTransactionManagerBuilder.build(initializer: initializer),
            transactionRepository: initializer.transactionRepository,
            utxoRepository: UTXORepositoryBuilder.build(initializer: initializer),
            blockProcessor: CompactBlockProcessor(
                initializer: initializer,
                walletBirthdayProvider: { initializer.walletBirthday }
            )
        )
    }

    init(
        status: SyncStatus,
        initializer: Initializer,
        transactionManager: OutboundTransactionManager,
        transactionRepository: TransactionRepository,
        utxoRepository: UnspentTransactionOutputRepository,
        blockProcessor: CompactBlockProcessor
    ) {
        self.connectionState = .idle
        self.underlyingStatus = status
        self.initializer = initializer
        self.transactionManager = transactionManager
        self.transactionRepository = transactionRepository
        self.utxoRepository = utxoRepository
        self.blockProcessor = blockProcessor
        self.network = initializer.network

        subscribeToProcessorNotifications(blockProcessor)

        Task(priority: .high) { [weak self] in await self?.subscribeToProcessorEvents(blockProcessor) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { [blockProcessor] in
            await blockProcessor.stop()
        }
    }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) async throws -> Initializer.InitializationResult {
        guard status == .unprepared else { return .success }

        try utxoRepository.initialise()

        if case .seedRequired = try self.initializer.initialize(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday) {
            return .seedRequired
        }

        latestScannedHeight = (try? transactionRepository.lastScannedHeight()) ?? initializer.walletBirthday

        self.status = .disconnected

        return .success
    }

    /// Starts the synchronizer
    /// - Throws: CompactBlockProcessorError when failures occur
    public func start(retry: Bool = false) async throws {
        switch status {
        case .unprepared:
            throw SynchronizerError.notPrepared

        case .syncing, .enhancing, .fetching:
            LoggerProxy.warn("warning: Synchronizer started when already running. Next sync process will be started when the current one stops.")
            /// This may look strange but `CompactBlockProcessor` has mechanisms which can handle this situation. So we are fine with calling
            /// it's start here.
            await blockProcessor.start(retry: retry)

        case .stopped, .synced, .disconnected, .error:
            status = .syncing(.nullProgress)
            syncStartDate = Date()
            await blockProcessor.start(retry: retry)
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
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.connectionStateChanged)
        }
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
                    self?.status = .enhancing(.zero)

                case .startedFetching:
                    self?.status = .fetching

                case .startedSyncing:
                    self?.status = .syncing(.nullProgress)

                case .stopped:
                    self?.status = .stopped
                }
            }
            .store(in: &longLivingCancelables)
    }

    private func failed(error: CompactBlockProcessorError) {
        status = .error(self.mapError(error))
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
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.foundTransactions(transactions, range))
        }
    }

    private func handledReorg(reorgHeight: BlockHeight, rewindHeight: BlockHeight) {
        LoggerProxy.debug("handling reorg at: \(reorgHeight) with rewind height: \(rewindHeight)")

        do {
            try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            LoggerProxy.debug("error handling reorg: \(error)")
        }
    }

    private func progressUpdated(progress: CompactBlockProgress) {
        switch progress {
        case let .syncing(progress):
            status = .syncing(progress)
        case let .enhance(progress):
            status = .enhancing(progress)
        case .fetch:
            status = .fetching
        }
    }

    private func storedUTXOs(utxos: (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])) {
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.storedUTXOs(utxos.inserted, utxos.skipped))
        }
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
                spendSourceURL: initializer.saplingParamsSourceURL.spendParamFileURL,
                outputURL: initializer.outputParamsURL,
                outputSourceURL: initializer.saplingParamsSourceURL.outputParamFileURL
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

    // MARK: Rewind

    public func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error> {
        let subject = PassthroughSubject<Void, Error>()
        Task {
            let height: BlockHeight?

            switch policy {
            case .quick:
                height = nil

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

            let context = AfterSyncHooksManager.RewindContext(
                height: height,
                completion: { [weak self] result in
                    switch result {
                    case let .success(rewindHeight):
                        do {
                            try self?.transactionManager.handleReorg(at: rewindHeight)
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(SynchronizerError.rewindError(underlyingError: error)))
                        }

                    case let .failure(error):
                        subject.send(completion: .failure(error))
                    }
                }
            )

            await blockProcessor.rewind(context: context)
        }
        return subject.eraseToAnyPublisher()
    }

    // MARK: Wipe

    public func wipe() -> AnyPublisher<Void, Error> {
        let subject = PassthroughSubject<Void, Error>()
        Task(priority: .high) {
            let context = AfterSyncHooksManager.WipeContext(
                pendingDbURL: initializer.pendingDbURL,
                prewipe: { [weak self] in
                    self?.transactionManager.closeDBConnection()
                    self?.transactionRepository.closeDBConnection()
                },
                completion: { [weak self] possibleError in
                    self?.status = .unprepared
                    if let error = possibleError {
                        subject.send(completion: .failure(error))
                    } else {
                        subject.send(completion: .finished)
                    }
                }
            )

            await blockProcessor.wipe(context: context)
        }

        return subject.eraseToAnyPublisher()
    }

    // MARK: notify state

    private func snapshotState(status: SyncStatus) async -> SynchronizerState {
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

    private func notify(oldStatus: SyncStatus, newStatus: SyncStatus) {
        guard oldStatus != newStatus else { return }

        // When the wipe happens status is switched to `unprepared`. And we expect that everything is deleted. All the databases including data DB.
        // When new snapshot is created balance is checked. And when balance is checked and data DB doesn't exist then rust initialise new database.
        // So it's necessary to not create new snapshot after status is switched to `unprepared` otherwise data DB exists after wipe
        if newStatus == .unprepared {
            latestState = SynchronizerState.zero
            updateStateStream(with: latestState)
        } else {
            let didStatusChange = areTwoStatusesDifferent(firstStatus: oldStatus, secondStatus: newStatus)

            if didStatusChange {
                Task {
                    latestState = await snapshotState(status: newStatus)
                    updateStateStream(with: latestState)
                }
            } else {
                latestState = SynchronizerState(
                    shieldedBalance: latestState.shieldedBalance,
                    transparentBalance: latestState.transparentBalance,
                    syncStatus: newStatus,
                    latestScannedHeight: latestState.latestScannedHeight
                )
                updateStateStream(with: latestState)
            }
        }
    }

    private func areTwoStatusesDifferent(firstStatus: SyncStatus, secondStatus: SyncStatus) -> Bool {
        switch (firstStatus, secondStatus) {
        case (.unprepared, .unprepared): return false
        case (.syncing, .syncing): return false
        case (.enhancing, .enhancing): return false
        case (.fetching, .fetching): return false
        case (.synced, .synced): return false
        case (.stopped, .stopped): return false
        case (.disconnected, .disconnected): return false
        case (.error, .error): return false
        default: return true
        }
    }

    private func updateStateStream(with newState: SynchronizerState) {
        streamsUpdateQueue.async { [weak self] in
            self?.stateSubject.send(newState)
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
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.minedTransaction(transaction))
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func mapError(_ error: Error) -> SynchronizerError {
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
            case .saplingActivationMismatch:
                return SynchronizerError.lightwalletdValidationFailed(underlyingError: compactBlockProcessorError)
            case .unknown:
                break
            }
        }

        return SynchronizerError.uncategorized(underlyingError: error)
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
