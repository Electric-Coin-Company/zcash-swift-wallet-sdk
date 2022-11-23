//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Foundation
import XCTest
@testable import ZcashLightClientKit

/**
This is the TestCoordinator
What does it do? quite a lot.
Is it a nice "SOLID" "Clean Code" piece of source code?
Hell no. It's your testing overlord and you will be grateful it is.
*/
// swiftlint:disable force_try function_parameter_count
class TestCoordinator {
    enum CoordinatorError: Error {
        case notDarksideWallet
        case notificationFromUnknownSynchronizer
        case notMockLightWalletService
        case builderError
        case seedRequiredForMigration
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
    
    var completionHandler: ((SDKSynchronizer) throws -> Void)?
    var errorHandler: ((Error?) -> Void)?
    var spendingKey: UnifiedSpendingKey
    var birthday: BlockHeight
    var channelProvider: ChannelProvider
    var synchronizer: SDKSynchronizer
    var service: DarksideWalletService
    var spendingKeys: [UnifiedSpendingKey]?
    var databases: TemporaryTestDatabases
    let network: ZcashNetwork
    convenience init(
        seed: String,
        walletBirthday: BlockHeight,
        channelProvider: ChannelProvider,
        network: ZcashNetwork
    ) throws {
        let derivationTool = DerivationTool(networkType: network.networkType)

        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(
            seed: TestSeed().seed(),
            accountIndex: 0
        )

        let ufvk = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

        try self.init(
            spendingKey: spendingKey,
            unifiedFullViewingKey: ufvk,
            walletBirthday: walletBirthday,
            channelProvider: channelProvider,
            network: network
        )
    }
    
    required init(
        spendingKey: UnifiedSpendingKey,
        unifiedFullViewingKey: UnifiedFullViewingKey,
        walletBirthday: BlockHeight,
        channelProvider: ChannelProvider,
        network: ZcashNetwork
    ) throws {
        XCTestCase.wait { await InternalSyncProgress(storage: UserDefaults.standard).rewind(to: 0) }

        self.spendingKey = spendingKey
        self.birthday = walletBirthday
        self.channelProvider = channelProvider
        self.databases = TemporaryDbBuilder.build()
        self.network = network
        self.service = DarksideWalletService(
            service: LightWalletGRPCService(
                host: Constants.address,
                port: 9067,
                secure: false,
                singleCallTimeout: 10000,
                streamingCallTimeout: 1000000
            )
        )
        let storage = CompactBlockStorage(url: databases.cacheDB, readonly: false)
        try storage.createTable()
        
        let buildResult = try TestSynchronizerBuilder.build(
            rustBackend: ZcashRustBackend.self,
            lowerBoundHeight: self.birthday,
            cacheDbURL: databases.cacheDB,
            dataDbURL: databases.dataDB,
            pendingDbURL: databases.pendingDB,
            endpoint: LightWalletEndpointBuilder.default,
            service: self.service,
            repository: TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: databases.dataDB.absoluteString)),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: databases.dataDB,
                readOnly: true
            ),
            storage: storage,
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            spendingKey: spendingKey,
            unifiedFullViewingKey: unifiedFullViewingKey,
            walletBirthday: walletBirthday,
            network: network,
            loggerProxy: SampleLogger(logLevel: .debug)
        )
        
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
        case .url(let urlString, _):
            try service.useDataset(from: urlString)
        }
    }
    
    func setLatestHeight(height: BlockHeight) throws {
        try service.applyStaged(nextLatestHeight: height)
    }
    
    func sync(completion: @escaping (SDKSynchronizer) throws -> Void, error: @escaping (Error?) -> Void) throws {
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
    
    @objc func synchronizerSynced(_ notification: Notification) throws {
        if case .stopped = self.synchronizer.status {
            LoggerProxy.debug("WARNING: notification received after synchronizer was stopped")
            return
        }
        try self.completionHandler?(self.synchronizer)
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

extension CompactBlockProcessor {
    public func setConfig(_ config: Configuration) {
        self.config = config
    }
}

extension TestCoordinator {
    func resetBlocks(dataset: DarksideData) throws {
        switch dataset {
        case .default:
            try service.useDataset(DarksideDataset.beforeReOrg.rawValue)
        case .predefined(let blocks):
            try service.useDataset(blocks.rawValue)
        case .url(let urlString, _):
            try service.useDataset(urlString)
        }
    }
    
    func stageBlockCreate(height: BlockHeight, count: Int = 1, nonce: Int = 0) throws {
        try service.stageBlocksCreate(from: height, count: count, nonce: 0)
    }
    
    func applyStaged(blockheight: BlockHeight) throws {
        try service.applyStaged(nextLatestHeight: blockheight)
    }
    
    func stageTransaction(_ transaction: RawTransaction, at height: BlockHeight) throws {
        try service.stageTransaction(transaction, at: height)
    }
    
    func stageTransaction(url: String, at height: BlockHeight) throws {
        try service.stageTransaction(from: url, at: height)
    }
    
    func latestHeight() throws -> BlockHeight {
        try service.latestBlockHeight()
    }
    
    func reset(saplingActivation: BlockHeight, branchID: String, chainName: String) throws {
        Task {
            await self.synchronizer.blockProcessor.stop()
            let config = await self.synchronizer.blockProcessor.config

            let newConfig = CompactBlockProcessor.Configuration(
                cacheDb: config.cacheDb,
                dataDb: config.dataDb,
                spendParamsURL: config.spendParamsURL,
                outputParamsURL: config.outputParamsURL,
                downloadBatchSize: config.downloadBatchSize,
                retries: config.retries,
                maxBackoffInterval: config.maxBackoffInterval,
                rewindDistance: config.rewindDistance,
                walletBirthday: config.walletBirthday,
                saplingActivation: saplingActivation,
                network: config.network
            )

            await self.synchronizer.blockProcessor.setConfig(newConfig)
        }

        try service.reset(saplingActivation: saplingActivation, branchID: branchID, chainName: chainName)
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

enum TemporaryDbBuilder {
    static func build() -> TemporaryTestDatabases {
        let tempUrl = try! __documentsDirectory()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        return TemporaryTestDatabases(
            cacheDB: tempUrl.appendingPathComponent("cache_db_\(timestamp).db"),
            dataDB: tempUrl.appendingPathComponent("data_db_\(timestamp).db"),
            pendingDB: tempUrl.appendingPathComponent("pending_db_\(timestamp).db")
        )
    }
}

enum TestSynchronizerBuilder {
    static func build(
        rustBackend: ZcashRustBackendWelding.Type,
        lowerBoundHeight: BlockHeight,
        cacheDbURL: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        accountRepository: AccountRepository,
        storage: CompactBlockStorage,
        spendParamsURL: URL,
        outputParamsURL: URL,
        spendingKey: UnifiedSpendingKey,
        unifiedFullViewingKey: UnifiedFullViewingKey,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        seed: [UInt8]? = nil,
        loggerProxy: Logger? = nil
    ) throws -> (spendingKeys: [UnifiedSpendingKey]?, synchronizer: SDKSynchronizer) {
        let initializer = Initializer(
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            network: network,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            viewingKeys: [unifiedFullViewingKey],
            walletBirthday: walletBirthday,
            alias: "",
            loggerProxy: loggerProxy
        )

        let synchronizer = try SDKSynchronizer(initializer: initializer)
        if case .seedRequired = try synchronizer.prepare(with: seed) {
            throw TestCoordinator.CoordinatorError.seedRequiredForMigration
        }
        
        return ([spendingKey], synchronizer)
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
        accountRepository: AccountRepository,
        storage: CompactBlockStorage,
        spendParamsURL: URL,
        outputParamsURL: URL,
        seedBytes: [UInt8],
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        loggerProxy: Logger? = nil
    ) async throws -> (spendingKeys: [UnifiedSpendingKey]?, synchronizer: SDKSynchronizer) {
        let spendingKey = try DerivationTool(networkType: network.networkType)
                .deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: 0)

        
        let uvk = try DerivationTool(networkType: network.networkType)
            .deriveUnifiedFullViewingKey(from: spendingKey)

        return try build(
            rustBackend: rustBackend,
            lowerBoundHeight: lowerBoundHeight,
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: service,
            repository: repository,
            accountRepository: accountRepository,
            storage: storage,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            spendingKey: spendingKey,
            unifiedFullViewingKey: uvk,
            walletBirthday: walletBirthday,
            network: network
        )
    }
}
