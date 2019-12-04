//
//  SDKSynchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/6/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import UIKit

/**
 Synchronizer implementation  for UIKit  and iOS 12+
 */
public class SDKSynchronizer: Synchronizer {
    
    public private(set) var status: Status
    public private(set) var progress: Float = 0.0
    public private(set) var blockProcessor: CompactBlockProcessor?
    public private(set) var initializer: Initializer
    
    private var transactionManager: OutboundTransactionManager
    
    var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private var isBackgroundAllowed: Bool {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return true
        default:
            return false
        }
    }
    
    public init(initializer: Initializer) {
        self.status = .disconnected
        self.initializer = initializer
        self.transactionManager = OutboundTransactionManagerBuilder.build(initializer: initializer)
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
        
        guard status == .stopped || status == .disconnected else {
            assert(true,"warning:  synchronizer started when already started") // TODO: remove this assertion some time in the near future
            return
        }
        
        subscribeToProcessorNotifications(processor)
        
        registerBackgroundActivity()
        try processor.start()
        
        self.blockProcessor = processor
    }
    
    public func stop() throws {
        
        guard status != .stopped, status != .disconnected else { return }
        
        guard let processor = self.blockProcessor else { return }
        
        processor.stop(cancelTasks: true)
    }
    
    private func subscribeToAppDelegateNotifications() {
        // todo: ios 13 platform specific
        
        let center = NotificationCenter.default
        
        center.addObserver(self,
                           selector: #selector(applicationDidBecomeActive(_:)),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
        
        center.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification,
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
                           selector: #selector(processorTransitionUnknown(_:)),
                           name: Notification.Name.blockProcessorUnknownTransition,
                           object: processor)
    }
    
    @objc func processorUpdated(_ notification: Notification) {
        guard let progress = notification.userInfo?[CompactBlockProcessorNotificationKey.progress] as? Float else {
            return
        }
        
        self.progress = progress
    }
    
    // MARK: Block Processor notifications
    
    @objc func processorStartedDownloading(_ notification: Notification) {
        self.status = .syncing
    }
    
    @objc func processorStartedValidating(_ notification: Notification) {
        self.status = .syncing
    }
    
    @objc func processorStartedScanning(_ notification: Notification) {
        self.status = .syncing
    }
    
    @objc func processorStopped(_ notification: Notification) {
        self.status = .stopped
    }
    
    @objc func processorFailed(_ notification: Notification) {
        self.status = .disconnected
    }
    
    @objc func processorIdle(_ notification: Notification) {
        self.status = .disconnected
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
    
    public func sendToAddress(spendingKey: String, zatoshi: Int64, toAddress: String, memo: String?, from accountIndex: Int, resultBlock: @escaping (Result<PendingTransactionEntity, Error>) -> Void) {
        
        do {
            let spend = try transactionManager.initSpend(zatoshi: Int(zatoshi), toAddress: toAddress, memo: memo, from: accountIndex)
            
            transactionManager.encode(spendingKey: spendingKey, pendingTransaction: spend) { (result) in
                switch result {
                    
                case .success(let tx):
                    resultBlock(.success(tx))
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
    
}
