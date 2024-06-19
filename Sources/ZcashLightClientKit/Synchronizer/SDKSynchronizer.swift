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

    let metrics: SDKMetrics
    public let logger: Logger

    // Don't read this variable directly. Use `status` instead. And don't update this variable directly use `updateStatus()` methods instead.
    private var underlyingStatus: GenericActor<InternalSyncStatus>
    var status: InternalSyncStatus {
        get async { await underlyingStatus.value }
    }

    let blockProcessor: CompactBlockProcessor
    lazy var blockProcessorEventProcessingQueue = { DispatchQueue(label: "blockProcessorEventProcessingQueue_\(initializer.alias.description)") }()

    public let initializer: Initializer
    public var connectionState: ConnectionState
    public let network: ZcashNetwork
    private let transactionEncoder: TransactionEncoder
    private let transactionRepository: TransactionRepository

    private let syncSessionIDGenerator: SyncSessionIDGenerator
    private let syncSession: SyncSession
    private let syncSessionTicker: SessionTicker
    var latestBlocksDataProvider: LatestBlocksDataProvider

    /// Creates an SDKSynchronizer instance
    /// - Parameter initializer: a wallet Initializer object
    public convenience init(initializer: Initializer) {
        self.init(
            status: .unprepared,
            initializer: initializer,
            transactionEncoder: WalletTransactionEncoder(initializer: initializer),
            transactionRepository: initializer.transactionRepository,
            blockProcessor: CompactBlockProcessor(
                initializer: initializer,
                walletBirthdayProvider: { initializer.walletBirthday }
            ),
            syncSessionTicker: .live
        )
    }

    init(
        status: InternalSyncStatus,
        initializer: Initializer,
        transactionEncoder: TransactionEncoder,
        transactionRepository: TransactionRepository,
        blockProcessor: CompactBlockProcessor,
        syncSessionTicker: SessionTicker
    ) {
        self.connectionState = .idle
        self.underlyingStatus = GenericActor(status)
        self.initializer = initializer
        self.transactionEncoder = transactionEncoder
        self.transactionRepository = transactionRepository
        self.blockProcessor = blockProcessor
        self.network = initializer.network
        self.metrics = initializer.container.resolve(SDKMetrics.self)
        self.logger = initializer.logger
        self.syncSessionIDGenerator = initializer.container.resolve(SyncSessionIDGenerator.self)
        self.syncSession = SyncSession(.nullID)
        self.syncSessionTicker = syncSessionTicker
        self.latestBlocksDataProvider = initializer.container.resolve(LatestBlocksDataProvider.self)
        
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

    func updateStatus(_ newValue: InternalSyncStatus, updateExternalStatus: Bool = true) async {
        let oldValue = await underlyingStatus.update(newValue)
        logger.info("Synchronizer's status updated from \(oldValue) to \(newValue)")
        await notify(oldStatus: oldValue, newStatus: newValue, updateExternalStatus: updateExternalStatus)
    }

    func throwIfUnprepared() throws {
        if !latestState.internalSyncStatus.isPrepared {
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
        walletBirthday: BlockHeight,
        for walletMode: WalletInitMode
    ) async throws -> Initializer.InitializationResult {
        guard await status == .unprepared else { return .success }

        if let error = checkIfCanContinueInitialisation() {
            throw error
        }

        if case .seedRequired = try await self.initializer.initialize(with: seed, walletBirthday: walletBirthday, for: walletMode) {
            return .seedRequired
        }
        
        await latestBlocksDataProvider.updateWalletBirthday(initializer.walletBirthday)
        await latestBlocksDataProvider.updateScannedData()
        
        await updateStatus(.disconnected, updateExternalStatus: false)

        return .success
    }

    /// Starts the synchronizer
    /// - Throws: ZcashError when failures occur
    public func start(retry: Bool = false) async throws {
        switch await status {
        case .unprepared:
            throw ZcashError.synchronizerNotPrepared

        case .syncing:
            logger.warn("warning: Synchronizer started when already running. Next sync process will be started when the current one stops.")
            /// This may look strange but `CompactBlockProcessor` has mechanisms which can handle this situation. So we are fine with calling
            /// it's start here.
            await blockProcessor.start(retry: retry)

        case .stopped, .synced, .disconnected, .error:
            let syncProgress = (try? await initializer.rustBackend.getWalletSummary()?.scanProgress?.progress()) ?? 0
            await updateStatus(.syncing(syncProgress))
            await blockProcessor.start(retry: retry)
        }
    }

    /// Stops the synchronizer
    public func stop() {
        // Calling `await blockProcessor.stop()` make take some time. If the downloading of blocks is in progress then this method inside waits until
        // downloading is really done. Which could block execution of the code on the client side. So it's better strategy to spin up new task and
        // exit fast on client side.
        Task(priority: .high) {
            let status = await self.status
            guard status != .stopped, status != .disconnected else {
                logger.info("attempted to stop when status was: \(status)")
                return
            }

            await blockProcessor.stop()
        }
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

            case let .finished(height):
                await self?.finished(lastScannedHeight: height)

            case let .foundTransactions(transactions, range):
                self?.foundTransactions(transactions: transactions, in: range)

            case let .handledReorg(reorgHeight, rewindHeight):
                // log reorg information
                self?.logger.info("handling reorg at: \(reorgHeight) with rewind height: \(rewindHeight)")

            case let .progressUpdated(progress):
                await self?.progressUpdated(progress: progress)

            case .syncProgress:
                break
                
            case let .storedUTXOs(utxos):
                self?.storedUTXOs(utxos: utxos)

            case .startedEnhancing, .startedFetching, .startedSyncing:
                break

            case .stopped:
                await self?.updateStatus(.stopped)

            case .minedTransaction(let transaction):
                self?.notifyMinedTransaction(transaction)
            }
        }

        await processor.updateEventClosure(identifier: "SDKSynchronizer", closure: eventClosure)
    }

    private func failed(error: Error) async {
        await updateStatus(.error(error))
    }

    private func finished(lastScannedHeight: BlockHeight) async {
        await latestBlocksDataProvider.updateScannedData()

        await updateStatus(.synced)
    }

    private func foundTransactions(transactions: [ZcashTransaction.Overview], in range: CompactBlockRange) {
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.foundTransactions(transactions, range))
        }
    }

    private func progressUpdated(progress: Float) async {
        let newStatus = InternalSyncStatus(progress)
        await updateStatus(newStatus)
    }

    private func storedUTXOs(utxos: (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])) {
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.storedUTXOs(utxos.inserted, utxos.skipped))
        }
    }

    // MARK: Synchronizer methods

    public func proposeTransfer(accountIndex: Int, recipient: Recipient, amount: Zatoshi, memo: Memo?) async throws -> Proposal {
        try throwIfUnprepared()

        if case Recipient.transparent = recipient, memo != nil {
            throw ZcashError.synchronizerSendMemoToTransparentAddress
        }

        let proposal = try await transactionEncoder.proposeTransfer(
            accountIndex: accountIndex,
            recipient: recipient.stringEncoded,
            amount: amount,
            memoBytes: memo?.asMemoBytes()
        )

        return proposal
    }

    public func proposeShielding(
        accountIndex: Int,
        shieldingThreshold: Zatoshi,
        memo: Memo,
        transparentReceiver: TransparentAddress? = nil
    ) async throws -> Proposal? {
        try throwIfUnprepared()

        return try await transactionEncoder.proposeShielding(
            accountIndex: accountIndex,
            shieldingThreshold: shieldingThreshold,
            memoBytes: memo.asMemoBytes(),
            transparentReceiver: transparentReceiver?.stringEncoded
        )
    }

    public func proposefulfillingPaymentURI(
        _ uri: String,
        accountIndex: Int
    ) async throws -> Proposal {
        do {
            try throwIfUnprepared()
            return try await transactionEncoder.proposeFulfillingPaymentFromURI(
                uri,
                accountIndex: accountIndex
            )
        } catch ZcashError.rustCreateToAddress(let error) {
            throw ZcashError.rustProposeTransferFromURI(error)
        } catch {
            throw error
        }
    }

    public func createProposedTransactions(
        proposal: Proposal,
        spendingKey: UnifiedSpendingKey
    ) async throws -> AsyncThrowingStream<TransactionSubmitResult, Error> {
        try throwIfUnprepared()

        try await SaplingParameterDownloader.downloadParamsIfnotPresent(
            spendURL: initializer.spendParamsURL,
            spendSourceURL: initializer.saplingParamsSourceURL.spendParamFileURL,
            outputURL: initializer.outputParamsURL,
            outputSourceURL: initializer.saplingParamsSourceURL.outputParamFileURL,
            logger: logger
        )

        let transactions = try await transactionEncoder.createProposedTransactions(
            proposal: proposal,
            spendingKey: spendingKey
        )
        var iterator = transactions.makeIterator()
        var submitFailed = false

        return AsyncThrowingStream() {
            guard let transaction = iterator.next() else { return nil }

            if submitFailed {
                return .notAttempted(txId: transaction.rawID)
            } else {
                let encodedTransaction = try transaction.encodedTransaction()

                do {
                    try await self.transactionEncoder.submit(transaction: encodedTransaction)
                    return TransactionSubmitResult.success(txId: transaction.rawID)
                } catch ZcashError.serviceSubmitFailed(let error) {
                    submitFailed = true
                    return TransactionSubmitResult.grpcFailure(txId: transaction.rawID, error: error)
                } catch TransactionEncoderError.submitError(let code, let message) {
                    submitFailed = true
                    return TransactionSubmitResult.submitFailure(txId: transaction.rawID, code: code, description: message)
                }
            }
        }
    }

    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) async throws -> ZcashTransaction.Overview {
        try throwIfUnprepared()

        if case Recipient.transparent = toAddress, memo != nil {
            throw ZcashError.synchronizerSendMemoToTransparentAddress
        }

        try await SaplingParameterDownloader.downloadParamsIfnotPresent(
            spendURL: initializer.spendParamsURL,
            spendSourceURL: initializer.saplingParamsSourceURL.spendParamFileURL,
            outputURL: initializer.outputParamsURL,
            outputSourceURL: initializer.saplingParamsSourceURL.outputParamFileURL,
            logger: logger
        )

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
    ) async throws -> ZcashTransaction.Overview {
        try throwIfUnprepared()

        // let's see if there are funds to shield
        let accountIndex = Int(spendingKey.account)

        guard let tBalance = try await self.getAccountBalance(accountIndex: accountIndex)?.unshielded else {
            throw ZcashError.synchronizerSpendingKeyDoesNotBelongToTheWallet
        }

        // Verify that at least there are funds for the fee. Ideally this logic will be improved by the shielding wallet.
        guard tBalance >= self.network.constants.defaultFee() else {
            throw ZcashError.synchronizerShieldFundsInsuficientTransparentFunds
        }

        guard let proposal = try await transactionEncoder.proposeShielding(
            accountIndex: Int(spendingKey.account),
            shieldingThreshold: shieldingThreshold,
            memoBytes: memo.asMemoBytes(),
            transparentReceiver: nil
        ) else { throw ZcashError.synchronizerShieldFundsInsuficientTransparentFunds }

        let transactions = try await transactionEncoder.createProposedTransactions(
            proposal: proposal,
            spendingKey: spendingKey
        )

        assert(transactions.count == 1, "Rust backend doesn't produce multiple transactions yet")
        let transaction = transactions[0]

        let encodedTx = try transaction.encodedTransaction()

        try await transactionEncoder.submit(transaction: encodedTx)

        return transaction
    }

    func createToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        recipient: Recipient,
        memo: Memo?
    ) async throws -> ZcashTransaction.Overview {
        do {
            if
                case .transparent = recipient,
                memo != nil {
                throw ZcashError.synchronizerSendMemoToTransparentAddress
            }

            let proposal = try await transactionEncoder.proposeTransfer(
                accountIndex: Int(spendingKey.account),
                recipient: recipient.stringEncoded,
                amount: zatoshi,
                memoBytes: memo?.asMemoBytes()
            )

            let transactions = try await transactionEncoder.createProposedTransactions(
                proposal: proposal,
                spendingKey: spendingKey
            )

            assert(transactions.count == 1, "Rust backend doesn't produce multiple transactions yet")
            let transaction = transactions[0]

            let encodedTransaction = try transaction.encodedTransaction()

            try await transactionEncoder.submit(transaction: encodedTransaction)
            
            return transaction
        } catch {
            throw error
        }
    }

    public func allReceivedTransactions() async throws -> [ZcashTransaction.Overview] {
        try await transactionRepository.findReceived(offset: 0, limit: Int.max)
    }

    public func allTransactions() async throws -> [ZcashTransaction.Overview] {
        return try await transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
    }

    public func allSentTransactions() async throws -> [ZcashTransaction.Overview] {
        return try await transactionRepository.findSent(offset: 0, limit: Int.max)
    }

    public func allTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview] {
        return try await transactionRepository.find(from: transaction, limit: limit, kind: .all)
    }

    public func paginatedTransactions(of kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        PagedTransactionRepositoryBuilder.build(initializer: initializer, kind: .all)
    }

    public func getMemos(for rawID: Data) async throws -> [Memo] {
        return try await transactionRepository.findMemos(for: rawID)
    }

    public func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        return try await transactionRepository.findMemos(for: transaction.rawID)
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient] {
        return (try? await transactionRepository.getRecipients(for: transaction.rawID)) ?? []
    }

    public func getTransactionOutputs(for transaction: ZcashTransaction.Overview) async -> [ZcashTransaction.Output] {
        return (try? await transactionRepository.getTransactionOutputs(for: transaction.rawID)) ?? []
    }

    public func latestHeight() async throws -> BlockHeight {
        try await blockProcessor.latestHeight()
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        try throwIfUnprepared()
        return try await blockProcessor.refreshUTXOs(tAddress: address, startHeight: height)
    }

    public func getAccountBalance(accountIndex: Int = 0) async throws -> AccountBalance? {
        try await initializer.rustBackend.getWalletSummary()?.accountBalances[UInt32(accountIndex)]
    }

    public func getExchangeRateUSD() async throws -> NSDecimalNumber {
        logger.info("Bootstrapping Tor client for fetching exchange rates")
        let tor: TorClient
        do {
            tor = try await TorClient(torDir: initializer.torDirURL)
        } catch {
            logger.error("failed to bootstrap Tor client: \(error)")
            throw error
        }

        do {
            return try await tor.getExchangeRateUSD()
        } catch {
            logger.error("Failed to fetch exchange rate through Tor: \(error)")
            throw error
        }
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

    // MARK: Rewind

    public func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error> {
        let subject = PassthroughSubject<Void, Error>()
        Task(priority: .high) {
            if !latestState.internalSyncStatus.isPrepared {
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
                completion: { result in
                    switch result {
                    case .success:
                        subject.send(completion: .finished)

                    case let .failure(error):
                        subject.send(completion: .failure(error))
                    }
                }
            )

            do {
                try await blockProcessor.rewind(context: context)
            } catch {
                subject.send(completion: .failure(error))
            }
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
                prewipe: { [weak self] in
                    self?.transactionEncoder.closeDBConnection()
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

            do {
                try await blockProcessor.wipe(context: context)
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }

    public func isSeedRelevantToAnyDerivedAccount(seed: [UInt8]) async throws -> Bool {
        try await initializer.rustBackend.isSeedRelevantToAnyDerivedAccount(seed: seed)
    }

    // MARK: Server switch

    public func switchTo(endpoint: LightWalletEndpoint) async throws {
        // Stop synchronization
        let status = await self.status
        if status != .stopped && status != .disconnected {
            await blockProcessor.stop()
        }

        // Validation of the server is first because any custom endpoint can be passed here
        // Extra instance of the service is created with lower timeout ofr a single call
        initializer.container.register(type: LightWalletService.self, isSingleton: true) { _ in
            LightWalletGRPCService(
                host: endpoint.host,
                port: endpoint.port,
                secure: endpoint.secure,
                singleCallTimeout: 5000,
                streamingCallTimeout: endpoint.streamingCallTimeoutInMillis
            )
        }

        let validateSever = ValidateServerAction(
            container: initializer.container,
            configProvider: CompactBlockProcessor.ConfigProvider(config: await blockProcessor.config)
        )
 
        do {
            _ = try await validateSever.run(with: ActionContextImpl(state: .idle)) { _ in }
        } catch {
            throw ZcashError.synchronizerServerSwitch
        }
        
        // The `ValidateServerAction` confirmed the server is ok and we can continue
        // final instance of the service will be instantiated and propagated to the all parties

        // SWITCH TO NEW ENDPOINT
        
        // LightWalletService dependency update
        initializer.container.register(type: LightWalletService.self, isSingleton: true) { _ in
            LightWalletGRPCService(endpoint: endpoint)
        }

        // DEPENDENCIES

        // BlockDownloaderService dependency update
        initializer.container.register(type: BlockDownloaderService.self, isSingleton: true) { di in
            let service = di.resolve(LightWalletService.self)
            let storage = di.resolve(CompactBlockRepository.self)

            return BlockDownloaderServiceImpl(service: service, storage: storage)
        }

        // LatestBlocksDataProvider dependency update
        initializer.container.register(type: LatestBlocksDataProvider.self, isSingleton: true) { di in
            let service = di.resolve(LightWalletService.self)
            let rustBackend = di.resolve(ZcashRustBackendWelding.self)

            return LatestBlocksDataProviderImpl(service: service, rustBackend: rustBackend)
        }
        
        // CompactBlockProcessor dependency update
        Dependencies.setupCompactBlockProcessor(
            in: initializer.container,
            config: await blockProcessor.config
        )
        
        // INITIALIZER
        initializer.lightWalletService = initializer.container.resolve(LightWalletService.self)
        initializer.blockDownloaderService = initializer.container.resolve(BlockDownloaderService.self)
        initializer.endpoint = endpoint

        // SELF
        self.latestBlocksDataProvider = initializer.container.resolve(LatestBlocksDataProvider.self)
        
        // COMPACT BLOCK PROCESSOR
        await blockProcessor.updateService(initializer.container)
        
        // Start synchronization
        if status != .unprepared {
            try await start(retry: true)
        }
    }

    // MARK: notify state

    private func snapshotState(status: InternalSyncStatus) async -> SynchronizerState {
        await SynchronizerState(
            syncSessionID: syncSession.value,
            accountBalance: try? await getAccountBalance(),
            internalSyncStatus: status,
            latestBlockHeight: latestBlocksDataProvider.latestBlockHeight
        )
    }

    private func notify(oldStatus: InternalSyncStatus, newStatus: InternalSyncStatus, updateExternalStatus: Bool = true) async {
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

        if updateExternalStatus {
            updateStateStream(with: latestState)
        }
    }

    private func updateStateStream(with newState: SynchronizerState) {
        streamsUpdateQueue.async { [weak self] in
            self?.stateSubject.send(newState)
        }
    }

    private func notifyMinedTransaction(_ transaction: ZcashTransaction.Overview) {
        streamsUpdateQueue.async { [weak self] in
            self?.eventSubject.send(.minedTransaction(transaction))
        }
    }
}

extension SDKSynchronizer {
    public var transactions: [ZcashTransaction.Overview] {
        get async {
            (try? await self.allTransactions()) ?? []
        }
    }

    public var sentTransactions: [ZcashTransaction.Overview] {
        get async {
            (try? await allSentTransactions()) ?? []
        }
    }

    public var receivedTransactions: [ZcashTransaction.Overview] {
        get async {
            (try? await allReceivedTransactions()) ?? []
        }
    }
}

extension InternalSyncStatus {
    func isDifferent(from otherStatus: InternalSyncStatus) -> Bool {
        switch (self, otherStatus) {
        case (.unprepared, .unprepared): return false
        case (.syncing, .syncing): return false
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
    var isNewSyncSession: (InternalSyncStatus, InternalSyncStatus) -> Bool
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
