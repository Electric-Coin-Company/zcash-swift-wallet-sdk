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
}

/**
 Synchronizer implementation for UIKit and iOS 12+
 */
public class SDKSynchronizer: Synchronizer {

    public struct NotificationKeys {
        public static let progress = "SDKSynchronizer.progress"
        public static let blockHeight = "SDKSynchronizer.blockHeight"
        public static let minedTransaction = "SDKSynchronizer.minedTransaction"
        public static let foundTransactions = "SDKSynchronizer.foundTransactions"
        public static let error = "SDKSynchronizer.error"
    }
    
    private static let shieldingThreshold: Int = 10000
    
    public private(set) var status: Status {
        didSet {
            notify(status: status)
        }
    }
    public private(set) var progress: Float = 0.0
    public private(set) var blockProcessor: CompactBlockProcessor?
    public private(set) var initializer: Initializer
    
    private var transactionManager: OutboundTransactionManager
    private var transactionRepository: TransactionRepository
    private var utxoRepository: UnspentTransactionOutputRepository
    
    /**
     Creates an SDKSynchronizer instance
     - Parameter initializer: a wallet Initializer object
     */
    public convenience init(initializer: Initializer) throws {
        
        self.init(status: .disconnected,
                  initializer: initializer,
                  transactionManager:  try OutboundTransactionManagerBuilder.build(initializer: initializer),
                  transactionRepository: initializer.transactionRepository,
                  utxoRepository: try UTXORepositoryBuilder.build(initializer: initializer))
        
    }
    
    init(status: Status,
         initializer: Initializer,
         transactionManager: OutboundTransactionManager,
         transactionRepository: TransactionRepository,
         utxoRepository: UnspentTransactionOutputRepository) {
        self.status = status
        self.initializer = initializer
        self.transactionManager = transactionManager
        self.transactionRepository = transactionRepository
        self.utxoRepository = utxoRepository
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.blockProcessor?.stop()
        self.blockProcessor = nil
        
    }
    
    private func lazyInitialize() throws {
        guard self.blockProcessor == nil else { return }
        guard let processor = initializer.blockProcessor() else {
            throw SynchronizerError.generalError(message: "compact block processor initialization failed")
        }
        
        subscribeToProcessorNotifications(processor)
        
        self.blockProcessor = processor
    }
    /**
     Starts the synchronizer
     - Throws: CompactBlockProcessorError when failures occur
     */
    public func start(retry: Bool = false) throws {
        
        try lazyInitialize()
        
        guard let processor = self.blockProcessor else {
            throw SynchronizerError.generalError(message: "compact block processor initialization failed")
        }
        
        guard status == .stopped || status == .disconnected || status == .synced else {
            assert(true,"warning:  synchronizer started when already started") // TODO: remove this assertion sometime in the near future
            return
        }
        
        do {
            try processor.start(retry: retry)
        } catch {
            throw mapError(error)
        }
    }
    
    /**
    Stops the synchronizer
    */
    public func stop() {
     
        guard status != .stopped, status != .disconnected else { return }
        
        guard let processor = self.blockProcessor else { return }
        
        processor.stop(cancelTasks: true)
    }
    
    private func subscribeToProcessorNotifications(_ processor: CompactBlockProcessor) {
        let center = NotificationCenter.default
        
        center.addObserver(self,
                           selector: #selector(processorUpdated(_:)),
                           name: Notification.Name.blockProcessorUpdated,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorStartedDownloading(_:)),
                           name: Notification.Name.blockProcessorStartedDownloading,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorStartedValidating(_:)),
                           name: Notification.Name.blockProcessorStartedValidating,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorStartedScanning(_:)),
                           name: Notification.Name.blockProcessorStartedScanning,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorStopped(_:)),
                           name: Notification.Name.blockProcessorStopped,
                           object: processor)
        
        center.addObserver(self, selector: #selector(processorFailed(_:)),
                           name: Notification.Name.blockProcessorFailed,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorIdle(_:)),
                           name: Notification.Name.blockProcessorIdle,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorFinished(_:)),
                           name: Notification.Name.blockProcessorFinished,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(processorTransitionUnknown(_:)),
                           name: Notification.Name.blockProcessorUnknownTransition,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(reorgDetected(_:)),
                           name: Notification.Name.blockProcessorHandledReOrg,
                           object: processor)
        
        center.addObserver(self,
                           selector: #selector(transactionsFound(_:)),
                           name: Notification.Name.blockProcessorFoundTransactions,
                           object: processor)
        
    }
    
    // MARK: Block Processor notifications
    
    @objc func transactionsFound(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let foundTransactions = userInfo[CompactBlockProcessorNotificationKey.foundTransactions] as? [ConfirmedTransactionEntity] else {
            return
        }
        NotificationCenter.default.post(name: .synchronizerFoundTransactions, object: self, userInfo: [ NotificationKeys.foundTransactions : foundTransactions])
    }
    
    @objc func reorgDetected(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let progress = userInfo[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = userInfo[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight else {
                LoggerProxy.debug("error processing reorg notification")
                return }
        
        LoggerProxy.debug("handling reorg at: \(progress) with rewind height: \(rewindHeight)")
        do {
            try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            LoggerProxy.debug("error handling reorg: \(error)")
            notifyFailure(error)
        }
    }
    
    @objc func processorUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let progress = userInfo[CompactBlockProcessorNotificationKey.progress] as? Float,
            let height = userInfo[CompactBlockProcessorNotificationKey.progressHeight] as? BlockHeight else {
                return
        }
        
        self.progress = progress
        self.notify(progress: progress, height: height)
    }
    
    @objc func processorStartedDownloading(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.status = .syncing
        }
    }
    
    @objc func processorStartedValidating(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.status = .syncing
        }
    }
    
    @objc func processorStartedScanning(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.status = .syncing
        }
    }
    
    @objc func processorStopped(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
            self.status = .stopped
        }
    }
    
    @objc func processorFailed(_ notification: Notification) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = notification.userInfo?[CompactBlockProcessorNotificationKey.error] as? Error {
                self.notifyFailure(error)
            } else {
                self.notifyFailure(CompactBlockProcessorError.generalError(message: "This is strange. processorFailed Call received no error message"))
            }
            self.status = .disconnected
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
//        DispatchQueue.global().async {[ weak self ] in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshPendingTransactions()
                self.status = .synced
            }
//        }
    }
    
    @objc func processorTransitionUnknown(_ notification: Notification) {
        self.status = .disconnected
    }
    
    // MARK: Synchronizer methods
    
    public func sendToAddress(spendingKey: String, zatoshi: Int64, toAddress: String, memo: String?, from accountIndex: Int, resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        initializer.downloadParametersIfNeeded { (downloadResult) in
            DispatchQueue.main.async { [weak self] in
                switch downloadResult {
                case .success:
                    self?.createToAddress(spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo, from: accountIndex, resultBlock: resultBlock)
                case .failure(let error):
                    resultBlock(.failure(SynchronizerError.parameterMissing(underlyingError: error)))
                }
            }
        }
    }
    
    public func shieldFunds(spendingKey: String, transparentSecretKey: String, memo: String?, from accountIndex: Int, resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        // let's see if there are funds to shield
        let derivationTool = DerivationTool.default
        
        do {
            let tAddr = try derivationTool.deriveTransparentAddressFromPrivateKey(transparentSecretKey)
            let tBalance = try utxoRepository.balance(address: tAddr, latestHeight: self.latestDownloadedHeight())
            
            guard tBalance.confirmed > Self.shieldingThreshold else {
                resultBlock(.failure(ShieldFundsError.insuficientTransparentFunds))
                return
            }
            let vk = try derivationTool.deriveViewingKey(spendingKey: spendingKey)
            let zAddr = try derivationTool.deriveShieldedAddress(viewingKey: vk)
            
            let shieldingSpend = try transactionManager.initSpend(zatoshi: Int(tBalance.confirmed), toAddress: zAddr, memo: memo, from: 0)
            
            transactionManager.encodeShieldingTransaction(spendingKey: spendingKey, tsk: transparentSecretKey, pendingTransaction: shieldingSpend) {[weak self] (result) in
                guard let self = self else { return }
                switch result {
                    
                case .success(let tx):
                    self.transactionManager.submit(pendingTransaction: tx) { (submitResult) in
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
    
    func createToAddress(spendingKey: String, zatoshi: Int64, toAddress: String, memo: String?, from accountIndex: Int, resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        do {
            let spend = try transactionManager.initSpend(zatoshi: Int(zatoshi), toAddress: toAddress, memo: memo, from: accountIndex)
            
            transactionManager.encode(spendingKey: spendingKey, pendingTransaction: spend) { [weak self] (result) in
                guard let self = self else { return }
                switch result {
                    
                case .success(let tx):
                    self.transactionManager.submit(pendingTransaction: tx) { (submitResult) in
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
    public func getAddress(accountIndex: Int) -> String {
        initializer.getAddress(index: accountIndex) ?? ""
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
        
        initializer.lightWalletService.fetchUTXOs(for: address, result: { [weak self] r in
            guard let self = self else { return }
            switch r {
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
        })
    }
    
    public func cachedUTXOs(address: String) throws -> [UnspentTransactionOutputEntity] {
        try utxoRepository.getAll(address: address)
    }
    
    /**
     gets the unshielded balance for the given address.
     */
    public func latestUnshieldedBalance(address: String, result: @escaping (Result<UnshieldedBalance,Error>) -> Void) {
        latestUTXOs(address: address, result: { [weak self] (r) in
            
            guard let self = self else { return }
            switch r {
            case .success:
                do {
                    result(.success(try self.utxoRepository.balance(address: address, latestHeight: try self.latestDownloadedHeight())))
                } catch {
                    result(.failure(SynchronizerError.uncategorized(underlyingError: error)))
                }
            case .failure(let e):
                result(.failure(SynchronizerError.generalError(message: "\(e)")))
            }
        })
    }
    
    /**
        gets the last stored unshielded balance
     */
    public func getUnshieldedBalance(address: String) throws -> UnshieldedBalance {
        do {
            let latestHeight = try self.latestDownloadedHeight()
            return try utxoRepository.balance(address: address, latestHeight: latestHeight)
        } catch {
            throw SynchronizerError.uncategorized(underlyingError: error)
        }
    }
    
    // MARK: notify state
    private func notify(progress: Float, height: BlockHeight) {
        NotificationCenter.default.post(name: Notification.Name.synchronizerProgressUpdated, object: self, userInfo: [
            NotificationKeys.progress : progress,
            NotificationKeys.blockHeight : height])
    }
    
    private func notify(status: Status) {
        
        switch status {
        case .disconnected:
            NotificationCenter.default.post(name: Notification.Name.synchronizerDisconnected, object: self)
        case .stopped:
            NotificationCenter.default.post(name: Notification.Name.synchronizerStopped, object: self)
        case .synced:
            NotificationCenter.default.post(name: Notification.Name.synchronizerSynced, object: self)
        case .syncing:
            NotificationCenter.default.post(name: Notification.Name.synchronizerSyncing, object: self)
            
        }
    }
    // MARK: book keeping
    
    private func updateMinedTransactions() throws {
        try transactionManager.allPendingTransactions()?.filter( { $0.isSubmitSuccess && !$0.isMined } ).forEach( { pendingTx in
            guard let rawId = pendingTx.rawTransactionId else { return }
            let tx = try transactionRepository.findBy(rawId: rawId)
            
            guard let minedHeight = tx?.minedHeight else { return }
            
            let minedTx = try transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)
            
            notifyMinedTransaction(minedTx)
            
        })
    }
    
    private func removeConfirmedTransactions() throws {
        let latestHeight = try transactionRepository.lastScannedHeight()
        
        try transactionManager.allPendingTransactions()?.filter( {
            $0.minedHeight > 0 && abs($0.minedHeight - latestHeight) >= ZcashSDK.DEFAULT_STALE_TOLERANCE }
            ).forEach( {
                try transactionManager.delete(pendingTransaction: $0)
            } )
    }
    
    private func refreshPendingTransactions() {
        do {
            try updateMinedTransactions()
            try removeConfirmedTransactions()
        } catch {
            LoggerProxy.debug("error refreshing pending transactions: \(error)")
        }
    }
    
    private func notifyMinedTransaction(_ tx: PendingTransactionEntity) {
        DispatchQueue.main.async {
            [weak self] in
            guard let self = self else { return }
            
            NotificationCenter.default.post(name: Notification.Name.synchronizerMinedTransaction, object: self, userInfo: [NotificationKeys.minedTransaction : tx])
        }
    }
    
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
            case .grpcError(let statusCode, let message):
                return SynchronizerError.connectionError(status: statusCode, message: message)
            case .connectionTimeout:
                return SynchronizerError.networkTimeout
            case .unspecifiedError(let underlyingError):
                return SynchronizerError.uncategorized(underlyingError: underlyingError)
            case .criticalError:
                return SynchronizerError.criticalError
            }
        }
        return SynchronizerError.uncategorized(underlyingError: error)
    }
    
    private func notifyFailure(_ error: Error) {
        
        DispatchQueue.main.async {
            [weak self] in
        guard let self = self else { return }
            
            NotificationCenter.default.post(name: Notification.Name.synchronizerFailed, object: self, userInfo: [NotificationKeys.error : self.mapError(error)])
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
