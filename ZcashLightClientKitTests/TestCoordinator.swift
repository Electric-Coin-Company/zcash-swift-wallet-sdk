//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Foundation
@testable import ZcashLightClientKit

class TestCoordinator {
    
    enum CoordinatorError: Error {
        case notDarksideWallet
        case notificationFromUnknownSynchronizer
    }
    
    enum SyncThreshold {
        case upTo(height: BlockHeight)
        case latestHeight
    }
    
    enum ServiceType {
        case lightwallet
        case darksideLightwallet(dataset: DarksideData)
    }
    
    enum DarksideData {
        case `default`
        case url(urlString: String)
    }
    
    var serviceType: ServiceType
    var completionHandler: ((SDKSynchronizer) -> Void)?
    var errorHandler: ((Error?) -> Void)?
    var seed: String
    var birthday: BlockHeight
    var channelProvider: ChannelProvider
    var synchronizer: SDKSynchronizer?
    var service: LightWalletService?
    var spendingKeys: [String]?
    
    init(serviceType: ServiceType = .lightwallet,
         seed: String,
         walletBirthday: BlockHeight,
         channelProvider: ChannelProvider) {
        self.serviceType = serviceType
        self.seed = seed
        self.birthday = walletBirthday
        self.channelProvider = channelProvider
    }
    
    func sync(to: SyncThreshold, completion: @escaping (SDKSynchronizer) -> Void, error: @escaping (Error?) -> Void) throws {
        self.completionHandler = completion
        self.errorHandler = error
        
        // TODO: instatiate synchronizer
        
    }
    
    func reorg(at: BlockHeight, backTo: BlockHeight) throws  {
        guard case ServiceType.darksideLightwallet = self.serviceType, let darksideWalletd = self.service as? DarksideWalletService else {
            throw CoordinatorError.notDarksideWallet
        }
        
        try darksideWalletd.triggerReOrg(latestHeight: at, reOrgHeight: backTo)
    }
    
    private func service(_ serviceStype: ServiceType) -> LightWalletService {
        switch serviceStype {
        case .darksideLightwallet:
            return DarksideWalletService()
        case .lightwallet:
            return LightWalletGRPCService(channel: channelProvider.channel())
        }
    }
    
    /**
     Notifications
     */
    func subscribeToNotifications(synchronizer: Synchronizer) {
        
        NotificationCenter.default.addObserver(self, selector: #selector(synchronizerFailed(_:)), name: .synchronizerFailed, object: synchronizer)
        NotificationCenter.default.addObserver(self, selector: #selector(synchronizerSynced(_:)), name: .synchronizerSynced, object: synchronizer)
        
    }
    
    @objc func synchronizerFailed(_ notification: Notification) {
        self.errorHandler?(notification.userInfo?[SDKSynchronizer.NotificationKeys.error] as? Error)
    }
    
    @objc func synchronizerSynced(_ notification: Notification) {
        guard let synchronizer = self.synchronizer else {
            self.errorHandler?(CoordinatorError.notificationFromUnknownSynchronizer)
            return
        }
        self.completionHandler?(synchronizer)
    }
    
    @objc func synchronizerDisconnected(_ notification: Notification) {
        /// TODO: See if we need hooks for this
    }
    
    @objc func synchronizerStarted(_ notification: Notification) {
        /// TODO: See if we need hooks for this
    }
    
    @objc func synchronizerStopped(_ notification: Notification) {
        /// TODO: See if we need hooks for this
    }
    
    @objc func synchronizerSyncing(_ notification: Notification) {
        /// TODO: See if we need hooks for this
    }
    
    
}


class TestSynchronizerBuilder {
    
    static func build(
        rustBackend: ZcashRustBackendWelding.Type,
        lowerBoundHeight: BlockHeight,
        cacheDbURL: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        service: LightWalletService,
        repository: TransactionRepository,
        downloader: CompactBlockDownloader,
        spendParamsURL: URL,
        outputParamsURL: URL,
        seedBytes: [UInt8],
        walletBirthday: WalletBirthday,
        loggerProxy: Logger? = nil
    ) throws -> (spendingKeys: [String]?, synchronizer: SDKSynchronizer) {
        
        let initializer = Initializer(
            rustBackend: rustBackend,
            lowerBoundHeight: lowerBoundHeight,
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            service: service,
            repository: repository,
            downloader: downloader,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            loggerProxy: loggerProxy
        )
        
        return (
            try initializer.initialize(seedProvider: StubSeedProvider(bytes: seedBytes), walletBirthdayHeight: walletBirthday.height),
            try SDKSynchronizer(initializer: initializer)
        )
    }
}

class StubSeedProvider: SeedProvider {
    
    let bytes: [UInt8]
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    func seed() -> [UInt8] {
        self.bytes
    }
}
