//
//  SDKSynchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/6/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import UIKit

public extension Notification.Name {
    /**
    Notification is posted whenever transactions are updated
     
    - Important: not yet posted
    */
    static let transactionsUpdated = Notification.Name("SDKSyncronizerTransactionUpdated")
    
    /**
    Posted when the synchronizer is started.
    */
    static let synchronizerStarted = Notification.Name("SDKSyncronizerStarted")
    
    /**
    Posted when there are progress updates.
     
    - Note: Query userInfo object for NotificationKeys.progress  for Float progress percentage and NotificationKeys.blockHeight  for the current progress height
    */
    static let synchronizerProgressUpdated = Notification.Name("SDKSyncronizerProgressUpdated")
    
    static let synchronizerStatusWillUpdate = Notification.Name("SDKSynchronizerStatusWillUpdate")

    /**
    Posted when the synchronizer is synced to latest height
    */
    static let synchronizerSynced = Notification.Name("SDKSyncronizerSynced")
    
    /**
    Posted when the synchronizer is stopped
    */
    static let synchronizerStopped = Notification.Name("SDKSyncronizerStopped")

    /**
    Posted when the synchronizer loses connection
    */
    static let synchronizerDisconnected = Notification.Name("SDKSyncronizerDisconnected")

    /**
    Posted when the synchronizer starts syncing
    */
    static let synchronizerSyncing = Notification.Name("SDKSyncronizerSyncing")
    
    /**
    Posted when synchronizer starts downloading blocks
    */
    static let synchronizerDownloading = Notification.Name("SDKSyncronizerDownloading")
    
    /**
    Posted when synchronizer starts validating blocks
    */
    static let synchronizerValidating = Notification.Name("SDKSyncronizerValidating")
    
    /**
    Posted when synchronizer starts scanning blocks
    */
    static let synchronizerScanning = Notification.Name("SDKSyncronizerScanning")
    
    /**
    Posted when the synchronizer starts Enhancing
    */
    static let synchronizerEnhancing = Notification.Name("SDKSyncronizerEnhancing")
    
    /**
    Posted when the synchronizer starts fetching UTXOs
    */
    static let synchronizerFetching = Notification.Name("SDKSyncronizerFetching")
    
    /**
    Posted when the synchronizer finds a pendingTransaction that hast been newly mined
    - Note: query userInfo on NotificationKeys.minedTransaction for the transaction
    */
    static let synchronizerMinedTransaction = Notification.Name("synchronizerMinedTransaction")
    
    /**
    Posted when the synchronizer finds a mined transaction
    - Note: query userInfo on NotificationKeys.foundTransactions for the [ConfirmedTransactionEntity]. This notification could arrive in a background thread.
    */
    static let synchronizerFoundTransactions = Notification.Name("synchronizerFoundTransactions")
    
    /**
    Posted when the synchronizer presents an error
    - Note: query userInfo on NotificationKeys.error for an error
    */
    static let synchronizerFailed = Notification.Name("SDKSynchronizerFailed")
    
    static let synchronizerConnectionStateChanged = Notification.Name("SynchronizerConnectionStateChanged")
}

/**
Synchronizer implementation for UIKit and iOS 12+
*/
// swiftlint:disable type_body_length
public class SDKSynchronizer: Synchronizer {
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
    }
    
    public private(set) var status: SyncStatus {
        didSet {
            notify(status: status)
        }
        willSet {
            notifyStatusChange(newValue: newValue, oldValue: status)
        }
    }
    public private(set) var progress: Float = 0.0
    public private(set) var blockProcessor: CompactBlockProcessor
    public private(set) var initializer: Initializer
    public private(set) var latestScannedHeight: BlockHeight
    public private(set) var connectionState: ConnectionState
    public private(set) var network: ZcashNetwork
    private var transactionManager: OutboundTransactionManager
    private var transactionRepository: TransactionRepository
    private var utxoRepository: UnspentTransactionOutputRepository

    /**
    Creates an SDKSynchronizer instance
    - Parameter initializer: a wallet Initializer object
    */
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
        self.status = status
        self.initializer = initializer
        self.transactionManager = transactionManager
        self.transactionRepository = transactionRepository
        self.utxoRepository = utxoRepository
        self.blockProcessor = blockProcessor
        self.latestScannedHeight = (try? transactionRepository.lastScannedHeight()) ?? initializer.walletBirthday.height
        self.network = initializer.network
        self.subscribeToProcessorNotifications(blockProcessor)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.blockProcessor.stop()
    }
    
    public func initialize() throws {
        try self.initializer.initialize()
        try self.blockProcessor.setStartHeight(initializer.walletBirthday.height)
    }
    
    public func prepare() throws {
        try self.initializer.initialize()
        try self.blockProcessor.setStartHeight(initializer.walletBirthday.height)
        self.status = .disconnected
    }

    /**
    Starts the synchronizer
    - Throws: CompactBlockProcessorError when failures occur
    */
    public func start(retry: Bool = false) throws {
        switch status {
        case .unprepared:
            throw SynchronizerError.notPrepared

        case .downloading, .validating, .scanning, .enhancing, .fetching:
            LoggerProxy.warn("warning: synchronizer started when already started")
            return

        case .stopped, .synced, .disconnected, .error:
            do {
                try blockProcessor.start(retry: retry)
            } catch {
                throw mapError(error)
            }
        }
    }
    
    /**
    Stops the synchronizer
    */
    public func stop() {
        guard status != .stopped, status != .disconnected else {
            LoggerProxy.info("attempted to stop when status was: \(status)")
            return
        }
        
        blockProcessor.stop(cancelTasks: true)
        self.status = .stopped
    }
    
    private func subscribeToProcessorNotifications(_ processor: CompactBlockProcessor) {
        let center = NotificationCenter.default
        
        center.addObserver(
            self,
            selector: #selector(processorUpdated(_:)),
            name: Notification.Name.blockProcessorUpdated,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStartedDownloading(_:)),
            name: Notification.Name.blockProcessorStartedDownloading,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStartedValidating(_:)),
            name: Notification.Name.blockProcessorStartedValidating,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStartedScanning(_:)),
            name: Notification.Name.blockProcessorStartedScanning,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStartedEnhancing(_:)),
            name: Notification.Name.blockProcessorStartedEnhancing,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStartedFetching(_:)),
            name: Notification.Name.blockProcessorStartedFetching,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorStopped(_:)),
            name: Notification.Name.blockProcessorStopped,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorFailed(_:)),
            name: Notification.Name.blockProcessorFailed,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorIdle(_:)),
            name: Notification.Name.blockProcessorIdle,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorFinished(_:)),
            name: Notification.Name.blockProcessorFinished,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(processorTransitionUnknown(_:)),
            name: Notification.Name.blockProcessorUnknownTransition,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(reorgDetected(_:)),
            name: Notification.Name.blockProcessorHandledReOrg,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(transactionsFound(_:)),
            name: Notification.Name.blockProcessorFoundTransactions,
            object: processor
        )
        
        center.addObserver(
            self,
            selector: #selector(connectivityStateChanged(_:)),
            name: Notification.Name.blockProcessorConnectivityStateChanged,
            object: nil
        )
    }
    
    // MARK: Block Processor notifications

    @objc func connectivityStateChanged(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let previous = userInfo[CompactBlockProcessorNotificationKey.previousConnectivityStatus] as? ConnectivityState,
            let current = userInfo[CompactBlockProcessorNotificationKey.currentConnectivityStatus] as? ConnectivityState
        else {
            LoggerProxy.error(
                "Found \(Notification.Name.blockProcessorConnectivityStateChanged) but lacks dictionary information." +
                "This is probably a programming error"
            )
            return
        }

        let currentState = ConnectionState(current)
        NotificationCenter.default.post(
            name: .synchronizerConnectionStateChanged,
            object: self,
            userInfo: [
                NotificationKeys.previousConnectionState: ConnectionState(previous),
                NotificationKeys.currentConnectionState: currentState
            ]
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = currentState
        }
    }
    
    @objc func transactionsFound(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let foundTransactions = userInfo[CompactBlockProcessorNotificationKey.foundTransactions] as? [ConfirmedTransactionEntity]
        else {
            return
        }

        NotificationCenter.default.post(
            name: .synchronizerFoundTransactions,
            object: self,
            userInfo: [
                NotificationKeys.foundTransactions: foundTransactions
            ]
        )
    }
    
    @objc func reorgDetected(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let progress = userInfo[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = userInfo[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight
        else {
            LoggerProxy.debug("error processing reorg notification")
            return
        }
        
        LoggerProxy.debug("handling reorg at: \(progress) with rewind height: \(rewindHeight)")

        do {
            try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            LoggerProxy.debug("error handling reorg: \(error)")
            notifyFailure(error)
        }
    }
    
    @objc func processorUpdated(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let progress = userInfo[CompactBlockProcessorNotificationKey.progress] as? CompactBlockProgress
        else {
            return
        }
    
        self.notify(progress: progress)
    }
    
    @objc func processorStartedDownloading(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .downloading(.nullProgress) else { return }
            self.status = .downloading(.nullProgress)
        }
    }
    
    @objc func processorStartedValidating(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .validating else { return }
            self.status = .validating
        }
    }
    
    @objc func processorStartedScanning(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .scanning(.nullProgress) else { return }
            self.status = .scanning(.nullProgress)
        }
    }
    @objc func processorStartedEnhancing(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .enhancing(NullEnhancementProgress()) else { return }
            self.status = .enhancing(NullEnhancementProgress())
        }
    }
    
    @objc func processorStartedFetching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .fetching else { return }
            self.status = .fetching
        }
    }
    
    @objc func processorStopped(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.status != .stopped else { return }
            self.status = .stopped
        }
    }
    
    @objc func processorFailed(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = notification.userInfo?[CompactBlockProcessorNotificationKey.error] as? Error {
                self.notifyFailure(error)
                self.status = .error(self.mapError(error))
            } else {
                self.notifyFailure(
                    CompactBlockProcessorError.generalError(
                        message: "This is strange. processorFailed Call received no error message"
                    )
                )
                self.status = .error(SynchronizerError.generalError(message: "This is strange. processorFailed Call received no error message"))
            }
        }
    }
    
    @objc func processorIdle(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
            self.status = .disconnected
        }
    }
    
    @objc func processorFinished(_ notification: Notification) {
        // FIX: Pending transaction updates fail if done from another thread. Improvement needed: explicitly define queues for sql repositories
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let blockHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.latestScannedBlockHeight] as? BlockHeight {
                    self.latestScannedHeight = blockHeight
                }
                self.refreshPendingTransactions()
                self.status = .synced
            }
    }
    
    @objc func processorTransitionUnknown(_ notification: Notification) {
        self.status = .disconnected
    }
    
    // MARK: Synchronizer methods

    // swiftlint:disable:next function_parameter_count
    public func sendToAddress(
        spendingKey: String,
        zatoshi: Int64,
        toAddress: String,
        memo: String?,
        from accountIndex: Int,
        resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void
    ) {
        initializer.downloadParametersIfNeeded { downloadResult in
            DispatchQueue.main.async { [weak self] in
                switch downloadResult {
                case .success:
                    self?.createToAddress(
                        spendingKey: spendingKey,
                        zatoshi: zatoshi,
                        toAddress: toAddress,
                        memo: memo,
                        from: accountIndex,
                        resultBlock: resultBlock
                    )
                case .failure(let error):
                    resultBlock(.failure(SynchronizerError.parameterMissing(underlyingError: error)))
                }
            }
        }
    }
    
    public func shieldFunds(
        spendingKey: String,
        transparentSecretKey: String,
        memo: String?,
        from accountIndex: Int,
        resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void
    ) {
        // let's see if there are funds to shield
        let derivationTool = DerivationTool(networkType: self.network.networkType)
        
        do {
            let tAddr = try derivationTool.deriveTransparentAddressFromPrivateKey(transparentSecretKey)
            let tBalance = try utxoRepository.balance(address: tAddr, latestHeight: self.latestDownloadedHeight())
            
            // Verify that at least there are funds for the fee. Ideally this logic will be improved by the shielding wallet.
            guard tBalance.verified >= self.network.constants.defaultFee(for: self.latestScannedHeight) else {
                resultBlock(.failure(ShieldFundsError.insuficientTransparentFunds))
                return
            }
            let viewingKey = try derivationTool.deriveViewingKey(spendingKey: spendingKey)
            let zAddr = try derivationTool.deriveShieldedAddress(viewingKey: viewingKey)
            
            let shieldingSpend = try transactionManager.initSpend(zatoshi: Int(tBalance.verified), toAddress: zAddr, memo: memo, from: 0)
            
            transactionManager.encodeShieldingTransaction(
                spendingKey: spendingKey,
                tsk: transparentSecretKey,
                pendingTransaction: shieldingSpend
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let transaction):
                    self.transactionManager.submit(pendingTransaction: transaction) { submitResult in
                        switch submitResult {
                        case .success(let submittedTx):
                            resultBlock(.success(submittedTx))
                        case .failure(let submissionError):
                            DispatchQueue.main.async {
                                resultBlock(.failure(submissionError))
                            }
                        }
                    }
                    
                case .failure(let error):
                    resultBlock(.failure(error))
                }
            }
        } catch {
            resultBlock(.failure(error))
            return
        }
    }

    // swiftlint:disable:next function_parameter_count
    func createToAddress(
        spendingKey: String,
        zatoshi: Int64,
        toAddress: String,
        memo: String?,
        from accountIndex: Int,
        resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void
    ) {
        do {
            let spend = try transactionManager.initSpend(
                zatoshi: Int(zatoshi),
                toAddress: toAddress,
                memo: memo,
                from: accountIndex
            )
            
            transactionManager.encode(spendingKey: spendingKey, pendingTransaction: spend) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let transaction):
                    self.transactionManager.submit(pendingTransaction: transaction) { submitResult in
                        switch submitResult {
                        case .success(let submittedTx):
                            resultBlock(.success(submittedTx))
                        case .failure(let submissionError):
                            DispatchQueue.main.async {
                                resultBlock(.failure(submissionError))
                            }
                        }
                    }
                    
                case .failure(let error):
                    resultBlock(.failure(error))
                }
            }
        } catch {
            resultBlock(.failure(error))
        }
    }
    
    public func cancelSpend(transaction: PendingTransactionEntity) -> Bool {
        transactionManager.cancel(pendingTransaction: transaction)
    }
    
    public func allReceivedTransactions() throws -> [ConfirmedTransactionEntity] {
        try transactionRepository.findAllReceivedTransactions(offset: 0, limit: Int.max) ?? [ConfirmedTransactionEntity]()
    }
    
    public func allPendingTransactions() throws -> [PendingTransactionEntity] {
        try transactionManager.allPendingTransactions() ?? [PendingTransactionEntity]()
    }
    
    public func allClearedTransactions() throws -> [ConfirmedTransactionEntity] {
        try transactionRepository.findAll(offset: 0, limit: Int.max) ?? [ConfirmedTransactionEntity]()
    }
    
    public func allSentTransactions() throws -> [ConfirmedTransactionEntity] {
        try transactionRepository.findAllSentTransactions(offset: 0, limit: Int.max) ?? [ConfirmedTransactionEntity]()
    }
    
    public func allConfirmedTransactions(from transaction: ConfirmedTransactionEntity?, limit: Int) throws -> [ConfirmedTransactionEntity]? {
        try transactionRepository.findAll(from: transaction, limit: limit)
    }
    
    public func paginatedTransactions(of kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        PagedTransactionRepositoryBuilder.build(initializer: initializer, kind: .all)
    }
    
    public func latestDownloadedHeight() throws -> BlockHeight {
        try initializer.downloader.lastDownloadedBlockHeight()
    }
    
    public func latestHeight(result: @escaping (Result<BlockHeight, Error>) -> Void) {
        initializer.downloader.latestBlockHeight(result: result)
    }
    
    public func latestHeight() throws -> BlockHeight {
        try initializer.downloader.latestBlockHeight()
    }
    
    public func latestUTXOs(address: String, result: @escaping (Result<[UnspentTransactionOutputEntity], Error>) -> Void) {
        guard initializer.isValidTransparentAddress(address) else {
            result(.failure(SynchronizerError.generalError(message: "invalid t-address")))
            return
        }
        
        initializer.lightWalletService.fetchUTXOs(for: address, height: network.constants.saplingActivationHeight) { [weak self] fetchResult in
            guard let self = self else { return }
            switch fetchResult {
            case .success(let utxos):
                do {
                    try self.utxoRepository.clearAll(address: address)
                    try self.utxoRepository.store(utxos: utxos)
                    result(.success(utxos))
                } catch {
                    result(.failure(SynchronizerError.generalError(message: "\(error)")))
                }
            case .failure(let error):
                result(.failure(SynchronizerError.connectionFailed(message: error)))
            }
        }
    }
   
    public func refreshUTXOs(address: String, from height: BlockHeight, result: @escaping (Result<RefreshedUTXOs, Error>) -> Void) {
        self.blockProcessor.refreshUTXOs(tAddress: address, startHeight: height, result: result)
    }
    
    public func getShieldedBalance(accountIndex: Int = 0) -> Int64 {
        initializer.getBalance(account: accountIndex)
    }
    
    public func getShieldedVerifiedBalance(accountIndex: Int = 0) -> Int64 {
        initializer.getVerifiedBalance(account: accountIndex)
    }
    
    public func getShieldedAddress(accountIndex: Int) -> SaplingShieldedAddress? {
        blockProcessor.getShieldedAddress(accountIndex: accountIndex)
    }
    
    public func getUnifiedAddress(accountIndex: Int) -> UnifiedAddress? {
        blockProcessor.getUnifiedAddres(accountIndex: accountIndex)
    }
    
    public func getTransparentAddress(accountIndex: Int) -> TransparentAddress? {
        blockProcessor.getTransparentAddress(accountIndex: accountIndex)
    }
    
    public func getTransparentBalance(accountIndex: Int) throws -> WalletBalance {
        try blockProcessor.getTransparentBalance(accountIndex: accountIndex)
    }
    
    /**
    Returns the last stored unshielded balance
    */
    public func getTransparentBalance(address: String) throws -> WalletBalance {
        do {
            return try self.blockProcessor.utxoCacheBalance(tAddress: address)
        } catch {
            throw SynchronizerError.uncategorized(underlyingError: error)
        }
    }
    
    public func rewind(_ policy: RewindPolicy) throws {
        self.stop()
        
        var height: BlockHeight?
        
        switch policy {
        case .quick:
            break

        case .birthday:
            let birthday = self.blockProcessor.config.walletBirthday
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
            let rewindHeight = try self.blockProcessor.rewindTo(height)
            try self.transactionManager.handleReorg(at: rewindHeight)
        } catch {
            throw SynchronizerError.rewindError(underlyingError: error)
        }
    }
    
    // MARK: notify state
    private func notify(progress: CompactBlockProgress) {
        var userInfo: [AnyHashable: Any] = .init()
        userInfo[NotificationKeys.progress] = progress
        userInfo[NotificationKeys.blockHeight] = progress.progressHeight

        self.status = SyncStatus(progress)
        NotificationCenter.default.post(name: Notification.Name.synchronizerProgressUpdated, object: self, userInfo: userInfo)
    }
    
    private func notifyStatusChange(newValue: SyncStatus, oldValue: SyncStatus) {
        NotificationCenter.default.post(
            name: .synchronizerStatusWillUpdate,
            object: self,
            userInfo:
                [
                    NotificationKeys.currentStatus: oldValue,
                    NotificationKeys.nextStatus: newValue
                ]
        )
    }
    
    private func notify(status: SyncStatus) {
        switch status {
        case .disconnected:
            NotificationCenter.default.post(name: Notification.Name.synchronizerDisconnected, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.synchronizerStopped, object: self)
        case .synced:
            NotificationCenter.default.post(
                name: Notification.Name.synchronizerSynced,
                object: self,
                userInfo: [
                    SDKSynchronizer.NotificationKeys.blockHeight: self.latestScannedHeight
                ]
            )
        case .unprepared:
            break
        case .downloading:
            NotificationCenter.default.post(name: Notification.Name.synchronizerDownloading, object: self)
        case .validating:
            NotificationCenter.default.post(name: Notification.Name.synchronizerValidating, object: self)
        case .scanning:
            NotificationCenter.default.post(name: Notification.Name.synchronizerScanning, object: self)
        case .enhancing:
            NotificationCenter.default.post(name: Notification.Name.synchronizerEnhancing, object: self)
        case .fetching:
            NotificationCenter.default.post(name: Notification.Name.synchronizerFetching, object: self)
        case .error(let e):
            self.notifyFailure(e)
        }
    }
    // MARK: book keeping
    
    private func updateMinedTransactions() throws {
        try transactionManager.allPendingTransactions()?
            .filter { $0.isSubmitSuccess && !$0.isMined }
            .forEach { pendingTx in
                guard let rawId = pendingTx.rawTransactionId else { return }
                let transaction = try transactionRepository.findBy(rawId: rawId)

                guard let minedHeight = transaction?.minedHeight else { return }
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
            
            NotificationCenter.default.post(
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
            case .saplingActivationMismatch:
                return SynchronizerError.lightwalletdValidationFailed(underlyingError: compactBlockProcessorError)
            }
        }
        
        return SynchronizerError.uncategorized(underlyingError: error)
    }
    
    private func notifyFailure(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(
                name: Notification.Name.synchronizerFailed,
                object: self,
                userInfo: [NotificationKeys.error: self.mapError(error)]
            )
        }
    }
}

extension SDKSynchronizer {
    public var pendingTransactions: [PendingTransactionEntity] {
        (try? self.allPendingTransactions()) ?? [PendingTransactionEntity]()
    }
    
    public var clearedTransactions: [ConfirmedTransactionEntity] {
        (try? self.allClearedTransactions()) ?? [ConfirmedTransactionEntity]()
    }
    
    public var sentTransactions: [ConfirmedTransactionEntity] {
        (try? self.allSentTransactions()) ?? [ConfirmedTransactionEntity]()
    }
    
    public var receivedTransactions: [ConfirmedTransactionEntity] {
        (try? self.allReceivedTransactions()) ?? [ConfirmedTransactionEntity]()
    }
}

import GRPC
extension ConnectionState {
    init(_ connectivityState: ConnectivityState) {
        switch connectivityState {
        case .connecting:
            self = .connecting
        case .idle:
            self = .idle
        case .ready:
            self = .online
        case .shutdown:
            self = .shutdown
        case .transientFailure:
            self = .reconnecting
        }
    }
}

extension BlockProgress {
    static var nullProgress: Self {
        return .init(startHeight: 0, targetHeight: 0, progressHeight: 0)
    }
}

private struct NullEnhancementProgress: EnhancementProgress {
    var totalTransactions: Int { 0 }
    var enhancedTransactions: Int { 0 }
    var lastFoundTransaction: ConfirmedTransactionEntity? { nil }
    var range: CompactBlockRange { 0 ... 0 }
}
