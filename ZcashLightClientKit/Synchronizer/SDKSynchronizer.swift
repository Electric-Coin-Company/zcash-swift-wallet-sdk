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
class SDKSynchronizer: Synchronizer {
    
    var status: Status
    
    var progress: Float = 0.0
    
    var blockProcessor: CompactBlockProcessor?
    
    var initializer: Initializer
    
    var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private var isBackgroundAllowed: Bool {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return true
        default:
            return false
        }
    }
    
    init(initializer: Initializer) {
        self.status = .disconnected
        self.initializer = initializer
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.blockProcessor?.stop()
        self.blockProcessor = nil
        self.taskIdentifier = .invalid
    }
    
    func start() throws {
        
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
    
    func stop() throws {
        
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
}
