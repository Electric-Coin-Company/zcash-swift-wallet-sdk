//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Foundation
@testable import ZcashLightClientKit

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
        case builderError
    }
    
    enum SyncThreshold {
        case upTo(height: BlockHeight)
        case latestHeight
    }
    
    enum DarksideData {
        case `default`
        case predefined(dataset: DarksideDataset)
        case url(urlString: String, startHeigth: BlockHeight)
    }
    
    var completionHandler: ((SDKSynchronizer) -> Void)?
    var errorHandler: ((Error?) -> Void)?
    var spendingKey: String
    var birthday: BlockHeight
    var channelProvider: ChannelProvider
    var synchronizer: SDKSynchronizer
    var service: DarksideWalletService
    var spendingKeys: [String]?
    var databases: TemporaryTestDatabases
    
     convenience init(seed: String,
         walletBirthday: BlockHeight,
         channelProvider: ChannelProvider) throws {
        guard let spendingKey = try DerivationTool.default.deriveSpendingKeys(seed: TestSeed().seed(),// todo: fix this
                                                                              numberOfAccounts: 1).first else {
            throw CoordinatorError.builderError
        }
        try self.init(spendingKey: spendingKey, walletBirthday: walletBirthday, channelProvider: channelProvider)
    }
    
    required init(spendingKey: String,
         walletBirthday: BlockHeight,
         channelProvider: ChannelProvider) throws {
        self.spendingKey = spendingKey
        self.birthday = walletBirthday
        self.channelProvider = channelProvider
        self.databases = TemporaryDbBuilder.build()
        self.service = DarksideWalletService()
        let storage = CompactBlockStorage(url: databases.cacheDB, readonly: false)
        try storage.createTable()
        
        let downloader = CompactBlockDownloader(service: self.service, storage: storage)
        
        
        let buildResult = try TestSynchronizerBuilder.build(
                                rustBackend: ZcashRustBackend.self,
                                lowerBoundHeight: self.birthday,
                                cacheDbURL: databases.cacheDB,
                                dataDbURL: databases.dataDB,
                                pendingDbURL: databases.pendingDB,
                                endpoint: LightWalletEndpointBuilder.default,
                                service: self.service,
                                repository: TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: databases.dataDB.absoluteString)),
                                downloader: downloader,
                                spendParamsURL: try __spendParamsURL(),
                                outputParamsURL: try __outputParamsURL(),
                                spendingKey: spendingKey,
                                walletBirthday: WalletBirthday.birthday(with: birthday),
                                loggerProxy: SampleLogger(logLevel: .debug))
        
        self.synchronizer = buildResult.synchronizer
        self.spendingKeys = buildResult.spendingKeys
        subscribeToNotifications(synchronizer: self.synchronizer)
    }
    
    func stop() throws {
        synchronizer.stop()
        self.completionHandler = nil
        self.errorHandler = nil
        
    }
    
    func setDarksideWalletState(_ state: DarksideData) throws {
       
        switch state {
        case .default:
            try service.useDataset(DarksideDataset.beforeReOrg.rawValue)
        case .predefined(let dataset):
            try service.useDataset(dataset.rawValue)
        case .url(let urlString,_):
            try service.useDataset(from: urlString)
        }
        
    }
    
    func setLatestHeight(height: BlockHeight) throws {
        try service.applyStaged(nextLatestHeight: height)
    }
    
    func sync(completion: @escaping (SDKSynchronizer) -> Void, error: @escaping (Error?) -> Void) throws {
        self.completionHandler = completion
        self.errorHandler = error
        
        try synchronizer.start(retry: true)
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
        if case .stopped = self.synchronizer.status {
            LoggerProxy.debug("WARNING: notification received after synchronizer was stopped")
            return
        }
        self.completionHandler?(self.synchronizer)
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
    
        switch dataset {
        case .default:
            try service.useDataset(DarksideDataset.beforeReOrg.rawValue)
        case .predefined(let blocks):
            try service.useDataset(blocks.rawValue)
        case .url(let urlString,_):
            try service.useDataset(urlString)
        }
    }
    
    func stageBlockCreate(height: BlockHeight, count: Int = 1, nonce: Int = 0) throws {
        try service.stageBlocksCreate(from: height, count: count, nonce: 0)
    }
    
    func applyStaged(blockheight: BlockHeight) throws {
        try service.applyStaged(nextLatestHeight: blockheight)
    }
    
    func stageTransaction(_ tx: RawTransaction, at height: BlockHeight) throws {
        try service.stageTransaction(tx, at: height)
    }
    
    func stageTransaction(url: String, at height: BlockHeight) throws {
        try service.stageTransaction(from: url, at: height)
    }
    
    func latestHeight() throws -> BlockHeight {
        try service.latestBlockHeight()
    }
    
    func reset(saplingActivation: BlockHeight) throws {
        try service.reset(saplingActivation: saplingActivation)
    }
    
    func getIncomingTransactions() throws -> [RawTransaction]? {
        return try service.getIncomingTransactions()
    }
}

struct TemporaryTestDatabases {
       var cacheDB: URL
       var dataDB: URL
       var pendingDB: URL
}

class TemporaryDbBuilder {

    static func build() -> TemporaryTestDatabases {
        let tempUrl = try! __documentsDirectory()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
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
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        downloader: CompactBlockDownloader,
        spendParamsURL: URL,
        outputParamsURL: URL,
        spendingKey: String,
        walletBirthday: WalletBirthday,
        loggerProxy: Logger? = nil
    ) throws -> (spendingKeys: [String]?, synchronizer: SDKSynchronizer)  {
        let initializer = Initializer(
            rustBackend: rustBackend,
            lowerBoundHeight: lowerBoundHeight,
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            chainNetwork: "ZEC",
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: service,
            repository: repository,
            downloader: downloader,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            loggerProxy: loggerProxy
        )
        try initializer.initialize(viewingKeys: [try DerivationTool().deriveViewingKey(spendingKey: spendingKey)], walletBirthday: walletBirthday.height)
        
        return ([spendingKey], try SDKSynchronizer(initializer: initializer)
        )
    }
    static func build(
        rustBackend: ZcashRustBackendWelding.Type,
        lowerBoundHeight: BlockHeight,
        cacheDbURL: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        downloader: CompactBlockDownloader,
        spendParamsURL: URL,
        outputParamsURL: URL,
        seedBytes: [UInt8],
        walletBirthday: WalletBirthday,
        loggerProxy: Logger? = nil
    ) throws -> (spendingKeys: [String]?, synchronizer: SDKSynchronizer) {
        guard let spendingKey = try DerivationTool().deriveSpendingKeys(seed: seedBytes, numberOfAccounts: 1).first else {
            throw TestCoordinator.CoordinatorError.builderError
        }
        return try build(rustBackend: rustBackend,
            lowerBoundHeight: lowerBoundHeight,
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: service,
            repository: repository,
            downloader: downloader,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            spendingKey: spendingKey,
            walletBirthday: walletBirthday)
        
    }
}

