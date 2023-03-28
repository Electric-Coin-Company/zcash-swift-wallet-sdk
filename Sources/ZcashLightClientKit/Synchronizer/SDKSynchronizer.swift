//
//  SDKSynchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/6/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import Combine

/// Synchronizer implementation for UIKit and iOS 13+
// swiftlint:disable type_body_length
public class SDKSynchronizer: Synchronizer {
    public var alias: ZcashSynchronizerAlias { initializer.alias }

    private lazy var streamsUpdateQueue = { DispatchQueue(label: "streamsUpdateQueue_\(initializer.alias.description)") }()
    private let stateSubject = CurrentValueSubject<SynchronizerState, Never>(.zero)
    public var stateStream: AnyPublisher<SynchronizerState, Never> { stateSubject.eraseToAnyPublisher() }
    public private(set) var latestState: SynchronizerState = .zero

    private let eventSubject = PassthroughSubject<SynchronizerEvent, Never>()
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { eventSubject.eraseToAnyPublisher() }

    public let metrics: SDKMetrics
    public let logger: Logger
    
    // Don't read this variable directly. Use `status` instead. And don't update this variable directly use `updateStatus()` methods instead.
    private var underlyingStatus: GenericActor<SyncStatus>
    var status: SyncStatus {
        get async { await underlyingStatus.value }
    }

    let blockProcessor: CompactBlockProcessor
    lazy var blockProcessorEventProcessingQueue = { DispatchQueue(label: "blockProcessorEventProcessingQueue_\(initializer.alias.description)") }()

    public private(set) var initializer: Initializer
    // Valid value is stored here after `prepare` is called.
    public private(set) var latestScannedHeight: BlockHeight = .zero
    public private(set) var connectionState: ConnectionState
    public private(set) var network: ZcashNetwork
    private var transactionManager: OutboundTransactionManager
    private var transactionRepository: TransactionRepository
    private var utxoRepository: UnspentTransactionOutputRepository

    private var syncStartDate: Date?

    /// Creates an SDKSynchronizer instance
    /// - Parameter initializer: a wallet Initializer object
    public convenience init(initializer: Initializer) {
        let metrics = SDKMetrics()
        self.init(
            status: .unprepared,
            initializer: initializer,
            transactionManager: OutboundTransactionManagerBuilder.build(initializer: initializer),
            transactionRepository: initializer.transactionRepository,
            utxoRepository: UTXORepositoryBuilder.build(initializer: initializer),
            blockProcessor: CompactBlockProcessor(
                initializer: initializer,
                metrics: metrics,
                logger: initializer.logger,
                walletBirthdayProvider: { initializer.walletBirthday }
            ),
            metrics: metrics
        )
    }

    init(
        status: SyncStatus,
        initializer: Initializer,
        transactionManager: OutboundTransactionManager,
        transactionRepository: TransactionRepository,
        utxoRepository: UnspentTransactionOutputRepository,
        blockProcessor: CompactBlockProcessor,
        metrics: SDKMetrics
    ) {
        self.connectionState = .idle
        self.underlyingStatus = GenericActor(status)
        self.initializer = initializer
        self.transactionManager = transactionManager
        self.transactionRepository = transactionRepository
        self.utxoRepository = utxoRepository
        self.blockProcessor = blockProcessor
        self.network = initializer.network
        self.metrics = metrics
        self.logger = initializer.logger

        initializer.lightWalletService.connectionStateChange = { [weak self] oldState, newState in
            self?.connectivityStateChanged(oldState: oldState, newState: newState)
        }

        Task(priority: .high) { [weak self] in await self?.subscribeToProcessorEvents(blockProcessor) }
    }

    deinit {
        UsedAliasesChecker.stopUsing(alias: initializer.alias, id: initializer.id)
        NotificationCenter.default.removeObserver(self)
        Task { [blockProcessor] in
            await blockProcessor.stop()
        }
    }

    func updateStatus(_ newValue: SyncStatus) async {
        let oldValue = await underlyingStatus.update(newValue)
        await notify(oldStatus: oldValue, newStatus: newValue)
    }

    func throwIfUnprepared() throws {
        if !latestState.syncStatus.isPrepared {
            throw SynchronizerError.notPrepared
        }
    }

    func checkIfCanContinueInitialisation() -> InitializerError? {
        if let initialisationError = initializer.urlsParsingError {
            return initialisationError
        }

        if !UsedAliasesChecker.tryToUse(alias: initializer.alias, id: initializer.id) {
            return InitializerError.aliasAlreadyInUse(initializer.alias)
        }

        return nil
    }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) async throws -> Initializer.InitializationResult {
        guard await status == .unprepared else { return .success }

        if let error = checkIfCanContinueInitialisation() {
            throw error
        }

        try utxoRepository.initialise()

        if case .seedRequired = try self.initializer.initialize(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday) {
            return .seedRequired
        }

        latestScannedHeight = (try? await transactionRepository.lastScannedHeight()) ?? initializer.walletBirthday

        await updateStatus(.disconnected)

        return .success
    }

    /// Starts the synchronizer
    /// - Throws: CompactBlockProcessorError when failures occur
    public func start(retry: Bool = false) async throws {
        switch await status {
        case .unprepared:
            throw SynchronizerError.notPrepared

        case .syncing, .enhancing, .fetching:
            logger.warn("warning: Synchronizer started when already running. Next sync process will be started when the current one stops.")
            /// This may look strange but `CompactBlockProcessor` has mechanisms which can handle this situation. So we are fine with calling
            /// it's start here.
            await blockProcessor.start(retry: retry)

        case .stopped, .synced, .disconnected, .error:
            await updateStatus(.syncing(.nullProgress))
            syncStartDate = Date()
            await blockProcessor.start(retry: retry)
        }
    }

    /// Stops the synchronizer
    public func stop() async {
        let status = await self.status
        guard status != .stopped, status != .disconnected else {
            logger.info("attempted to stop when status was: \(status)")
            return
        }

        await blockProcessor.stop()
    }

    // MARK: Connectivity State

    func connectivityStateChanged(oldState: ConnectionState, newState: ConnectionState) {
        connectionState = newState
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.connectionStateChanged(newState))
        }
    }

    // MARK: Handle CompactBlockProcessor.Flow

    private func subscribeToProcessorEvents(_ processor: CompactBlockProcessor) async {
        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case let .failed(error):
                await self?.failed(error: error)

            case let .finished(height, foundBlocks):
                await self?.finished(lastScannedHeight: height, foundBlocks: foundBlocks)

            case let .foundTransactions(transactions, range):
                self?.foundTransactions(transactions: transactions, in: range)

            case let .handledReorg(reorgHeight, rewindHeight):
                await self?.handledReorg(reorgHeight: reorgHeight, rewindHeight: rewindHeight)

            case let .progressUpdated(progress):
                await self?.progressUpdated(progress: progress)

            case let .storedUTXOs(utxos):
                self?.storedUTXOs(utxos: utxos)

            case .startedEnhancing:
                await self?.updateStatus(.enhancing(.zero))

            case .startedFetching:
                await self?.updateStatus(.fetching)

            case .startedSyncing:
                await self?.updateStatus(.syncing(.nullProgress))

            case .stopped:
                await self?.updateStatus(.stopped)
            }
        }

        await processor.updateEventClosure(identifier: "SDKSynchronizer", closure: eventClosure)
    }

    private func failed(error: CompactBlockProcessorError) async {
        await updateStatus(.error(self.mapError(error)))
    }

    private func finished(lastScannedHeight: BlockHeight, foundBlocks: Bool) async {
        // FIX: Pending transaction updates fail if done from another thread. Improvement needed: explicitly define queues for sql repositories see: https://github.com/zcash/ZcashLightClientKit/issues/450
        latestScannedHeight = lastScannedHeight
        await refreshPendingTransactions()
        await updateStatus(.synced)

        if let syncStartDate {
            metrics.pushSyncReport(
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

    private func handledReorg(reorgHeight: BlockHeight, rewindHeight: BlockHeight) async {
        logger.debug("handling reorg at: \(reorgHeight) with rewind height: \(rewindHeight)")

        do {
            try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            logger.debug("error handling reorg: \(error)")
        }
    }

    private func progressUpdated(progress: CompactBlockProgress) async {
        let newStatus = SyncStatus(progress)
        await updateStatus(newStatus)
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
        try throwIfUnprepared()

        do {
            try await SaplingParameterDownloader.downloadParamsIfnotPresent(
                spendURL: initializer.spendParamsURL,
                spendSourceURL: initializer.saplingParamsSourceURL.spendParamFileURL,
                outputURL: initializer.outputParamsURL,
                outputSourceURL: initializer.saplingParamsSourceURL.outputParamFileURL,
                logger: logger
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
        try throwIfUnprepared()

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

    public func allReceivedTransactions() async throws -> [ZcashTransaction.Received] {
        try await transactionRepository.findReceived(offset: 0, limit: Int.max)
    }

    public func allPendingTransactions() throws -> [PendingTransactionEntity] {
        try transactionManager.allPendingTransactions()
    }

    public func allClearedTransactions() async throws -> [ZcashTransaction.Overview] {
        return try await transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
    }

    public func allSentTransactions() async throws -> [ZcashTransaction.Sent] {
        return try await transactionRepository.findSent(offset: 0, limit: Int.max)
    }

    public func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview] {
        return try await transactionRepository.find(from: transaction, limit: limit, kind: .all)
    }

    public func paginatedTransactions(of kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        PagedTransactionRepositoryBuilder.build(initializer: initializer, kind: .all)
    }

    public func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        return try await transactionRepository.findMemos(for: transaction)
    }

    public func getMemos(for receivedTransaction: ZcashTransaction.Received) async throws -> [Memo] {
        return try await transactionRepository.findMemos(for: receivedTransaction)
    }

    public func getMemos(for sentTransaction: ZcashTransaction.Sent) async throws -> [Memo] {
        return try await transactionRepository.findMemos(for: sentTransaction)
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient] {
        return await transactionRepository.getRecipients(for: transaction.id)
    }

    public func getRecipients(for transaction: ZcashTransaction.Sent) async -> [TransactionRecipient] {
        return await transactionRepository.getRecipients(for: transaction.id)
    }

    public func latestHeight() async throws -> BlockHeight {
        try await blockProcessor.blockDownloaderService.latestBlockHeight()
    }

    public func latestUTXOs(address: String) async throws -> [UnspentTransactionOutputEntity] {
        try throwIfUnprepared()

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
        try throwIfUnprepared()
        return try await blockProcessor.refreshUTXOs(tAddress: address, startHeight: height)
    }
    
    public func getShieldedBalance(accountIndex: Int = 0) -> Zatoshi {
        initializer.getBalance(account: accountIndex)
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
        Task(priority: .high) {
            if !latestState.syncStatus.isPrepared {
                subject.send(completion: .failure(SynchronizerError.notPrepared))
                return
            }

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
            if let error = checkIfCanContinueInitialisation() {
                subject.send(completion: .failure(error))
                return
            }

            let context = AfterSyncHooksManager.WipeContext(
                pendingDbURL: initializer.pendingDbURL,
                prewipe: { [weak self] in
                    self?.transactionManager.closeDBConnection()
                    self?.transactionRepository.closeDBConnection()
                },
                completion: { [weak self] possibleError in
                    await self?.updateStatus(.unprepared)
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

    private func notify(oldStatus: SyncStatus, newStatus: SyncStatus) async {
        guard oldStatus != newStatus else { return }

        let newState: SynchronizerState

        // When the wipe happens status is switched to `unprepared`. And we expect that everything is deleted. All the databases including data DB.
        // When new snapshot is created balance is checked. And when balance is checked and data DB doesn't exist then rust initialise new database.
        // So it's necessary to not create new snapshot after status is switched to `unprepared` otherwise data DB exists after wipe
        if newStatus == .unprepared {
            newState = SynchronizerState.zero
        } else {
            if areTwoStatusesDifferent(firstStatus: oldStatus, secondStatus: newStatus) {
                newState = await snapshotState(status: newStatus)
            } else {
                newState = SynchronizerState(
                    shieldedBalance: latestState.shieldedBalance,
                    transparentBalance: latestState.transparentBalance,
                    syncStatus: newStatus,
                    latestScannedHeight: latestState.latestScannedHeight
                )
            }
        }

        latestState = newState
        updateStateStream(with: latestState)
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

    private func updateMinedTransactions() async throws {
        let transactions = try transactionManager.allPendingTransactions()
            .filter { $0.isSubmitSuccess && !$0.isMined }

        for pendingTx in transactions {
            guard let rawID = pendingTx.rawTransactionId else { return }
            let transaction = try await transactionRepository.find(rawID: rawID)
            guard let minedHeight = transaction.minedHeight else { return }

            let minedTx = try transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)

            notifyMinedTransaction(minedTx)
        }
    }

    private func removeConfirmedTransactions() async throws {
        let latestHeight = try await transactionRepository.lastScannedHeight()

        try transactionManager.allPendingTransactions()
            .filter { $0.minedHeight > 0 && abs($0.minedHeight - latestHeight) >= ZcashSDK.defaultStaleTolerance }
            .forEach { try transactionManager.delete(pendingTransaction: $0) }
    }

    private func refreshPendingTransactions() async {
        do {
            try await updateMinedTransactions()
            try await removeConfirmedTransactions()
        } catch {
            logger.debug("error refreshing pending transactions: \(error)")
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
        get async {
            (try? await allClearedTransactions()) ?? []
        }
    }

    public var sentTransactions: [ZcashTransaction.Sent] {
        get async {
            (try? await allSentTransactions()) ?? []
        }
    }

    public var receivedTransactions: [ZcashTransaction.Received] {
        get async {
            (try? await allReceivedTransactions()) ?? []
        }
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
