//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Foundation
@testable import ZcashLightClientKit
import MnemonicKit

/**
 This is the TestCoordinator
 What does it do? quite a lot.
 Is it a nice "SOLID" "Clean Code" piece of source code?
 Hell no. It's your testing overlord and you will be grateful it is.
 */
class TestCoordinator {
    
    enum CoordinatorError: Error {
        case notDarksideWallet
        case notificationFromUnknownSynchronizer
        case notMockLightWalletService
    }
    
    enum SyncThreshold {
        case upTo(height: BlockHeight)
        case latestHeight
    }
    
    enum ServiceType {
        case lightwallet(threshold: SyncThreshold)
        case darksideLightwallet(threshold: SyncThreshold, dataset: DarksideData)
    }
    
    enum DarksideData {
        case `default`
        case predefined(dataset: DarksideWalletService.DarksideDataset)
        case url(urlString: String, startHeigth: BlockHeight)
    }
    
    var serviceType: ServiceType
    var completionHandler: ((SDKSynchronizer) -> Void)?
    var errorHandler: ((Error?) -> Void)?
    var seed: String
    var birthday: BlockHeight
    var channelProvider: ChannelProvider
    var synchronizer: SDKSynchronizer
    var service: LightWalletService
    var spendingKeys: [String]?
    var databases: TemporaryTestDatabases
    
    init(serviceType: ServiceType = .lightwallet(threshold: .latestHeight),
         seed: String,
         walletBirthday: BlockHeight,
         channelProvider: ChannelProvider) throws {
        self.serviceType = serviceType
        self.seed = seed
        self.birthday = walletBirthday
        self.channelProvider = channelProvider
        self.databases = TemporaryDbBuilder.build()
        self.service = Self.serviceFor(serviceType, channelProvider: channelProvider)
        let buildResult = try TestSynchronizerBuilder.build(
                                rustBackend: ZcashRustBackend.self,
                                lowerBoundHeight: self.birthday,
                                cacheDbURL: databases.cacheDB,
                                dataDbURL: databases.dataDB,
                                pendingDbURL: databases.pendingDB,
                                service: self.service,
                                repository: TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: databases.dataDB.absoluteString)),
                                downloader: CompactBlockDownloader(service: self.service, storage: CompactBlockStorage(url: databases.cacheDB, readonly: false)),
                                spendParamsURL: try __spendParamsURL(),
                                outputParamsURL: try __outputParamsURL(),
                                seedBytes: Mnemonic.deterministicSeedBytes(from: self.seed)!,
                                walletBirthday: WalletBirthday.birthday(with: birthday))
        
        self.synchronizer = buildResult.synchronizer
        self.spendingKeys = buildResult.spendingKeys
        subscribeToNotifications(synchronizer: self.synchronizer)
    }
    
    func setDarksideWalletState(_ state: DarksideData) throws {
        guard let darksideWallet = self.service as? DarksideWalletService else {
            throw CoordinatorError.notDarksideWallet
        }
        switch state {
        case .default:
            try darksideWallet.useDataset(DarksideWalletService.DarksideDataset.beforeReOrg.rawValue)
        case .predefined(let dataset):
            try darksideWallet.useDataset(dataset.rawValue)
        case .url(let urlString, let startHeight):
            try darksideWallet.useDataset(from: urlString, startHeight: startHeight)
        }
        
    }
    
    func setLatestHeight(height: BlockHeight) throws {
        if let mocklwdService = self.service as? MockLightWalletService  {
            mocklwdService.latestHeight = height
        } else if let darkLwdService = self.service as? DarksideWalletService {
            try darkLwdService.applyStaged(nextLatestHeight: height)
        } else {
            throw CoordinatorError.notDarksideWallet
        }
    }
    
    func sync(completion: @escaping (SDKSynchronizer) -> Void, error: @escaping (Error?) -> Void) throws {
        self.completionHandler = completion
        self.errorHandler = error
        
        try synchronizer.start()
    }
    
    private static func serviceFor(_ serviceStype: ServiceType, channelProvider: ChannelProvider) -> LightWalletService {
        switch serviceStype {
        case .darksideLightwallet:
            return DarksideWalletService()
        case .lightwallet(let threshold):
            switch threshold {
            case .latestHeight:
                return LightWalletGRPCService(channel: channelProvider.channel())
            case .upTo(let height):
                return MockLightWalletService(latestBlockHeight: height)
            }
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

extension TestCoordinator {
    func resetBlocks(dataset: DarksideData) throws {
        guard let service = self.service as? DarksideWalletService else {
            throw CoordinatorError.notDarksideWallet
        }
        
        try service.reset()
        switch dataset {
        case .default:
            try service.useDataset(DarksideWalletService.DarksideDataset.beforeReOrg.rawValue)
        case .predefined(let blocks):
            try service.useDataset(blocks.rawValue)
        case .url(let urlString, let startHeight):
            try service.useDataset(urlString, startHeight: startHeight)
        }
    }
    
    func generateNext() throws {
        
    }
    
    func stageBlockCreate(height: BlockHeight, count: Int = 1) throws {
        guard let dlwd = self.service as? DarksideWalletService else {
            throw CoordinatorError.notDarksideWallet
        }
        
    }
    
    func applyStaged(blockheight: BlockHeight) throws {
        
    }
    
    func stageTransaction(_ tx: RawTransaction, at height: BlockHeight) throws {
        guard let dlwd = self.service as? DarksideWalletService else {
            throw CoordinatorError.notDarksideWallet
        }
        
    }
    
    func latestHeight() throws -> BlockHeight {
        try service.latestBlockHeight()
    }
}

struct TemporaryTestDatabases {
       var cacheDB: URL
       var dataDB: URL
       var pendingDB: URL
}

class TemporaryDbBuilder {

    static func build() -> TemporaryTestDatabases {
        let tempUrl = FileManager.default.temporaryDirectory
        let timestamp = String(Date().timeIntervalSince1970)
        
        return TemporaryTestDatabases(cacheDB: tempUrl.appendingPathComponent("cache_db_\(timestamp).db"),
                                      dataDB: tempUrl.appendingPathComponent("data_db_\(timestamp).db"),
                                      pendingDB: tempUrl.appendingPathComponent("pending_db_\(timestamp).db"))
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
