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

    public let initializer: Initializer
    public var connectionState: ConnectionState
    public let network: ZcashNetwork
    private let transactionManager: OutboundTransactionManager
    private let transactionRepository: TransactionRepository
    private let utxoRepository: UnspentTransactionOutputRepository

    private let syncSessionIDGenerator: SyncSessionIDGenerator
    private let syncSession: SyncSession
    private let syncSessionTicker: SessionTicker
    private var syncStartDate: Date?
    let latestBlocksDataProvider: LatestBlocksDataProvider

    /// Creates an SDKSynchronizer instance
    /// - Parameter initializer: a wallet Initializer object
    public convenience init(initializer: Initializer) {
        let metrics = SDKMetrics()
        let latestBlocksDataProvider = LatestBlocksDataProviderImpl(
            service: initializer.lightWalletService,
            transactionRepository: initializer.transactionRepository
        )
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
                latestBlocksDataProvider: latestBlocksDataProvider,
                walletBirthdayProvider: { initializer.walletBirthday }
            ),
            metrics: metrics,
            syncSessionIDGenerator: UniqueSyncSessionIDGenerator(),
            syncSessionTicker: .live,
            latestBlocksDataProvider: latestBlocksDataProvider
        )
    }

    init(
        status: SyncStatus,
        initializer: Initializer,
        transactionManager: OutboundTransactionManager,
        transactionRepository: TransactionRepository,
        utxoRepository: UnspentTransactionOutputRepository,
        blockProcessor: CompactBlockProcessor,
        metrics: SDKMetrics,
        syncSessionIDGenerator: SyncSessionIDGenerator,
        syncSessionTicker: SessionTicker,
        latestBlocksDataProvider: LatestBlocksDataProvider
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
        self.syncSessionIDGenerator = syncSessionIDGenerator
        self.syncSession = SyncSession(.nullID)
        self.syncSessionTicker = syncSessionTicker
        self.latestBlocksDataProvider = latestBlocksDataProvider
        
        initializer.lightWalletService.connectionStateChange = { [weak self] oldState, newState in
            self?.connectivityStateChanged(oldState: oldState, newState: newState)
        }

        Task(priority: .high) { [weak self] in await self?.subscribeToProcessorEvents(blockProcessor) }
    }

    deinit {
        UsedAliasesChecker.stopUsing(alias: initializer.alias, id: initializer.id)
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
            throw ZcashError.synchronizerNotPrepared
        }
    }

    func checkIfCanContinueInitialisation() -> ZcashError? {
        if let initialisationError = initializer.urlsParsingError {
            return initialisationError
        }

        if !UsedAliasesChecker.tryToUse(alias: initializer.alias, id: initializer.id) {
            return .initializerAliasAlreadyInUse(initializer.alias)
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

        try await utxoRepository.initialise()

        if case .seedRequired = try await self.initializer.initialize(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday) {
            return .seedRequired
        }

        await latestBlocksDataProvider.updateWalletBirthday(initializer.walletBirthday)
        await latestBlocksDataProvider.updateScannedData()
        
        await updateStatus(.disconnected)

        return .success
    }

    /// Starts the synchronizer
    /// - Throws: ZcashError when failures occur
    public func start(retry: Bool = false) async throws {
        switch await status {
        case .unprepared:
            throw ZcashError.synchronizerNotPrepared

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

    private func failed(error: Error) async {
        await updateStatus(.error(error))
    }

    private func finished(lastScannedHeight: BlockHeight, foundBlocks: Bool) async {
        await latestBlocksDataProvider.updateScannedData()
        // FIX: Pending transaction updates fail if done from another thread. Improvement needed: explicitly define queues for sql repositories see: https://github.com/zcash/ZcashLightClientKit/issues/450
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
            try await transactionManager.handleReorg(at: rewindHeight)
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

        try await SaplingParameterDownloader.downloadParamsIfnotPresent(
            spendURL: initializer.spendParamsURL,
            spendSourceURL: initializer.saplingParamsSourceURL.spendParamFileURL,
            outputURL: initializer.outputParamsURL,
            outputSourceURL: initializer.saplingParamsSourceURL.outputParamFileURL,
            logger: logger
        )

        if case Recipient.transparent = toAddress, memo != nil {
            throw ZcashError.synchronizerSendMemoToTransparentAddress
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
        let tBalance = try await self.getTransparentBalance(accountIndex: accountIndex)
        
        // Verify that at least there are funds for the fee. Ideally this logic will be improved by the shielding wallet.
        guard tBalance.verified >= self.network.constants.defaultFee(for: await self.latestBlocksDataProvider.latestScannedHeight) else {
            throw ZcashError.synchronizerShieldFundsInsuficientTransparentFunds
        }
        
        let shieldingSpend = try await transactionManager.initSpend(
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
    }

    func createToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        recipient: Recipient,
        memo: Memo?
    ) async throws -> PendingTransactionEntity {
        let spend = try await transactionManager.initSpend(
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
    }

    public func cancelSpend(transaction: PendingTransactionEntity) async -> Bool {
        await transactionManager.cancel(pendingTransaction: transaction)
    }

    public func allReceivedTransactions() async throws -> [ZcashTransaction.Received] {
        try await transactionRepository.findReceived(offset: 0, limit: Int.max)
    }

    public func allPendingTransactions() async throws -> [PendingTransactionEntity] {
        try await transactionManager.allPendingTransactions()
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
            throw ZcashError.synchronizerLatestUTXOsInvalidTAddress
        }
        
        let stream = initializer.lightWalletService.fetchUTXOs(for: address, height: network.constants.saplingActivationHeight)
        
        // swiftlint:disable:next array_constructor
        var utxos: [UnspentTransactionOutputEntity] = []
        for try await transactionEntity in stream {
            utxos.append(transactionEntity)
        }
        try await self.utxoRepository.clearAll(address: address)
        try await self.utxoRepository.store(utxos: utxos)
        return utxos
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        try throwIfUnprepared()
        return try await blockProcessor.refreshUTXOs(tAddress: address, startHeight: height)
    }

    public func getShieldedBalance(accountIndex: Int = 0) async throws -> Zatoshi {
        let balance = try await initializer.rustBackend.getBalance(account: Int32(accountIndex))

        return Zatoshi(balance)
    }

    public func getShieldedVerifiedBalance(accountIndex: Int = 0) async throws -> Zatoshi {
        let balance = try await initializer.rustBackend.getVerifiedBalance(account: Int32(accountIndex))

        return Zatoshi(balance)
    }

    public func getUnifiedAddress(accountIndex: Int) async throws -> UnifiedAddress {
        try await blockProcessor.getUnifiedAddress(accountIndex: accountIndex)
    }

    public func getSaplingAddress(accountIndex: Int) async throws -> SaplingAddress {
        try await blockProcessor.getSaplingAddress(accountIndex: accountIndex)
    }

    public func getTransparentAddress(accountIndex: Int) async throws -> TransparentAddress {
        try await blockProcessor.getTransparentAddress(accountIndex: accountIndex)
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
                subject.send(completion: .failure(ZcashError.synchronizerNotPrepared))
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
                    throw ZcashError.synchronizerRewindUnknownArchorHeight
                }
                height = txHeight
            }

            let context = AfterSyncHooksManager.RewindContext(
                height: height,
                completion: { [weak self] result in
                    switch result {
                    case let .success(rewindHeight):
                        do {
                            try await self?.transactionManager.handleReorg(at: rewindHeight)
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(error))
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
        return await SynchronizerState(
            syncSessionID: syncSession.value,
            shieldedBalance: WalletBalance(
                verified: (try? await getShieldedVerifiedBalance()) ?? .zero,
                total: (try? await getShieldedBalance()) ?? .zero
            ),
            transparentBalance: (try? await blockProcessor.getTransparentBalance(accountIndex: 0)) ?? .zero,
            syncStatus: status,
            latestScannedHeight: latestBlocksDataProvider.latestScannedHeight,
            latestBlockHeight: latestBlocksDataProvider.latestBlockHeight,
            latestScannedTime: latestBlocksDataProvider.latestScannedTime
        )
    }

    private func notify(oldStatus: SyncStatus, newStatus: SyncStatus) async {
        guard oldStatus != newStatus else { return }

        let newState: SynchronizerState

        // When the wipe happens status is switched to `unprepared`. And we expect that everything is deleted. All the databases including data DB.
        // When new snapshot is created balance is checked. And when balance is checked and data DB doesn't exist then rust initialise new database.
        // So it's necessary to not create new snapshot after status is switched to `unprepared` otherwise data DB exists after wipe
        if newStatus == .unprepared {
            var nextState = SynchronizerState.zero

            let nextSessionID = await self.syncSession.update(.nullID)

            nextState.syncSessionID = nextSessionID
            newState = nextState
        } else {
            if SessionTicker.live.isNewSyncSession(oldStatus, newStatus) {
                await self.syncSession.newSession(with: self.syncSessionIDGenerator)
            }
            newState = await snapshotState(status: newStatus)
        }

        latestState = newState
        updateStateStream(with: latestState)
    }

    private func updateStateStream(with newState: SynchronizerState) {
        streamsUpdateQueue.async { [weak self] in
            self?.stateSubject.send(newState)
        }
    }

    // MARK: book keeping

    private func updateMinedTransactions() async throws {
        let transactions = try await transactionManager.allPendingTransactions()
            .filter { $0.isSubmitSuccess && !$0.isMined }

        for pendingTx in transactions {
            guard let rawID = pendingTx.rawTransactionId else { return }
            let transaction = try await transactionRepository.find(rawID: rawID)
            guard let minedHeight = transaction.minedHeight else { return }

            let minedTx = try await transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)

            notifyMinedTransaction(minedTx)
        }
    }

    private func removeConfirmedTransactions() async throws {
        let latestHeight = try await transactionRepository.lastScannedHeight()

        let transactions = try await transactionManager.allPendingTransactions()
            .filter { $0.minedHeight > 0 && abs($0.minedHeight - latestHeight) >= ZcashSDK.defaultStaleTolerance }

        for transaction in transactions {
            try await transactionManager.delete(pendingTransaction: transaction)
        }
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
}

extension SDKSynchronizer {
    public var pendingTransactions: [PendingTransactionEntity] {
        get async {
            (try? await self.allPendingTransactions()) ?? [PendingTransactionEntity]()
        }
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

extension SyncStatus {
    func isDifferent(from otherStatus: SyncStatus) -> Bool {
        switch (self, otherStatus) {
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
}

struct SessionTicker {
    /// Helper function to determine whether we are in front of a SyncSession change for a given syncStatus
    /// transition we consider that every sync attempt is a new sync session and should have it's unique UUID reported.
    var isNewSyncSession: (SyncStatus, SyncStatus) -> Bool
}

extension SessionTicker {
    static let live = SessionTicker { oldStatus, newStatus in
        // if the state hasn't changed to a different syncStatus member
        guard oldStatus.isDifferent(from: newStatus) else { return false }

        switch (oldStatus, newStatus) {
        case (.unprepared, .syncing):
            return true
        case (.error, .syncing),
            (.disconnected, .syncing),
            (.stopped, .syncing),
            (.synced, .syncing):
            return true
        default:
            return false
        }
    }
}
