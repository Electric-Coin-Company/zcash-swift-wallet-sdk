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
    static let transactionsUpdated = Notification.Name("SDKSyncronizerTransactionUpdates")
    static let synchronizerStarted = Notification.Name("SDKSyncronizerStarted")
    static let synchronizerProgressUpdated = Notification.Name("SDKSyncronizerProgressUpdated")
    static let synchronizerSynced = Notification.Name("SDKSyncronizerSynced")
    static let synchronizerStopped = Notification.Name("SDKSyncronizerStopped")
    static let synchronizerDisconnected = Notification.Name("SDKSyncronizerDisconnected")
    static let synchronizerSyncing = Notification.Name("SDKSyncronizerSyncing")
    static let synchronizerMinedTransaction = Notification.Name("synchronizerMinedTransaction")
}

/**
 Synchronizer implementation  for UIKit  and iOS 12+
 */
public class SDKSynchronizer: Synchronizer {
    
    public struct NotificationKeys {
        public static let progress = "SDKSynchronizer.progress"
        public static let blockHeight = "SDKSynchronizer.blockHeight"
        public static let minedTransaction = "SDKSynchronizer.minedTransaction"
    }
    
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
    
    var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private var isBackgroundAllowed: Bool {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return true
        default:
            return false
        }
    }
    
    public init(initializer: Initializer) throws {
        self.status = .disconnected
        self.initializer = initializer
        self.transactionManager = try OutboundTransactionManagerBuilder.build(initializer: initializer)
        self.transactionRepository = TransactionRepositoryBuilder.build(initializer: initializer)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.blockProcessor?.stop()
        self.blockProcessor = nil
        self.taskIdentifier = .invalid
    }
    
    public func start() throws {
        
        guard let processor = initializer.blockProcessor() else {
            throw SynchronizerError.initFailed
        }
        
        subscribeToProcessorNotifications(processor)
        registerBackgroundActivity()
        self.blockProcessor = processor
        guard status == .stopped || status == .disconnected || status == .synced else {
            assert(true,"warning:  synchronizer started when already started") // TODO: remove this assertion some time in the near future
            return
        }
  
        try processor.start()
       
    }
    
    public func stop() throws {
        
        guard status != .stopped, status != .disconnected else { return }
        
        guard let processor = self.blockProcessor else { return }
        
        processor.stop(cancelTasks: true)
    }
    // MARK: event subscription
    private func subscribeToAppDelegateNotifications() {
        // todo: ios 13 platform specific
        
        let center = NotificationCenter.default
        
        center.addObserver(self,
                           selector: #selector(applicationDidBecomeActive(_:)),
                           name: UIApplication.didBecomeActiveNotification,
                           object: nil)
        
        center.addObserver(self,
                           selector: #selector(applicationWillTerminate(_:)),
                           name: UIApplication.willTerminateNotification,
                           object: nil)
        
        center.addObserver(self,
                           selector: #selector(applicationWillResignActive(_:)),
                           name: UIApplication.willResignActiveNotification,
                           object: nil)
        
        center.addObserver(self,
                           selector: #selector(applicationDidEnterBackground(_:)),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
        
        center.addObserver(self,
                           selector: #selector(applicationWillEnterForeground(_:)),
                           name: UIApplication.willEnterForegroundNotification,
                           object: nil)
        
    }
    
    private func registerBackgroundActivity() {
        if self.taskIdentifier == .invalid {
            self.taskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                self.blockProcessor?.stop(cancelTasks: true)
                UIApplication.shared.endBackgroundTask(self.taskIdentifier)
                self.taskIdentifier = .invalid
            })
        }
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
        
    }
    
    // MARK: Block Processor notifications
    
    @objc func reorgDetected(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let progress = userInfo[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = userInfo[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight else {
                print("error processing reorg notification")
                return }
        
        print("handling reorg at: \(progress) with rewind height: \(rewindHeight)")
        do {
          try transactionManager.handleReorg(at: rewindHeight)
        } catch {
            print("error handling reorg: \(error)") // TODO: handle and propagate Error
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
        
        DispatchQueue.main.async { self.status = .syncing }
    }
    
    @objc func processorStartedValidating(_ notification: Notification) {
        DispatchQueue.main.async { self.status = .syncing }
    }
    
    @objc func processorStartedScanning(_ notification: Notification) {
        DispatchQueue.main.async { self.status = .syncing }
    }
    
    @objc func processorStopped(_ notification: Notification) {
        DispatchQueue.main.async { self.status = .stopped }
    }
    
    @objc func processorFailed(_ notification: Notification) {
        DispatchQueue.main.async { self.status = .disconnected }
    }
    
    @objc func processorIdle(_ notification: Notification) {
        DispatchQueue.main.async { self.status = .disconnected }
    }
    @objc func processorFinished(_ notification: Notification) {
        DispatchQueue.global().async {
            self.refreshPendingTransactions()
            DispatchQueue.main.async {
                self.status = .synced
            }
        }
    }
    
    @objc func processorTransitionUnknown(_ notification: Notification) {
        self.status = .disconnected
    }
    
    // MARK: application notifications
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        registerBackgroundActivity()
        do {
            try self.start()
        } catch {
            self.status = .disconnected
        }
    }
    
    @objc func applicationDidEnterBackground(_ notification: Notification) {
        if !self.isBackgroundAllowed {
            do {
                try self.stop()
            } catch {
                self.status = .disconnected
            }
        }
    }
    
    @objc func applicationWillEnterForeground(_ notification: Notification) {
        let status = self.status
        
        if status == .stopped || status == .disconnected {
            do {
                try start()
            } catch {
                self.status = .disconnected
            }
        }
    }
    
    @objc func applicationWillResignActive(_ notification: Notification) {
        do {
            try stop()
        } catch {
            print("stop failed with error: \(error)")
        }
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        do {
            try stop()
        } catch {}
    }
    
    // MARK: Synchronizer methods
    
    public func sendToAddress(spendingKey: String, zatoshi: Int64, toAddress: String, memo: String?, from accountIndex: Int32, resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        do {
            let spend = try transactionManager.initSpend(zatoshi: zatoshi, toAddress: toAddress, memo: memo, from: accountIndex)
            
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
    
    public func getAddress(accountIndex: Int32) -> String {
        initializer.getAddress(index: accountIndex) ?? ""
    }
    
    public func cancelSpend(transaction: PendingTransactionEntity) -> Bool {
        transactionManager.cancel(pendingTransaction: transaction)
    }
    
    public var pendingTransactions: [PendingTransactionEntity] {
        (try? transactionManager.allPendingTransactions()) ?? [PendingTransactionEntity]()
    }
    
    public var clearedTransactions: [ConfirmedTransactionEntity] {
        (try? transactionRepository.findAll(offset: 0, limit: Int.max)) ?? [ConfirmedTransactionEntity]()
    }
    
    public var sentTransactions: [ConfirmedTransactionEntity] {
        (try? transactionRepository.findAllSentTransactions(offset: 0, limit: Int.max)) ?? [ConfirmedTransactionEntity]()
    }
    
    public var receivedTransactions: [ConfirmedTransactionEntity] {
        (try? transactionRepository.findAllReceivedTransactions(offset: 0, limit: Int.max)) ?? [ConfirmedTransactionEntity]()
    }
    
    public func paginatedTransactions(of kind: TransactionKind = .all) -> PaginatedTransactionRepository {
        PagedTransactionRepositoryBuilder.build(initializer: initializer, kind: .all)
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
        
        try transactionManager.allPendingTransactions()?.filter( { abs($0.minedHeight - latestHeight) >= DEFAULT_REWIND_DISTANCE } ).forEach( { try transactionManager.delete(pendingTransaction: $0) } )
    }
    
    private func refreshPendingTransactions() {
        do {
            try updateMinedTransactions()
            try removeConfirmedTransactions()
        } catch {
            print("error refreshing pending transactions: \(error)")
        }
    }
    
    private func notifyMinedTransaction(_ tx: PendingTransactionEntity) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.synchronizerMinedTransaction, object: self, userInfo: [NotificationKeys.minedTransaction : tx])
        }
    }
}
