//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Combine
import Foundation
import XCTest
@testable import ZcashLightClientKit

/// This is the TestCoordinator
/// What does it do? quite a lot.
/// Is it a nice "SOLID" "Clean Code" piece of source code?
/// Hell no. It's your testing overlord and you will be grateful it is.
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

    var cancellables: [AnyCancellable] = []
    var completionHandler: ((SDKSynchronizer) throws -> Void)?
    var errorHandler: ((Error?) async -> Void)?
    var spendingKey: UnifiedSpendingKey
    let viewingKey: UnifiedFullViewingKey
    var birthday: BlockHeight
    var synchronizer: SDKSynchronizer
    var service: DarksideWalletService
    var databases: TemporaryTestDatabases
    let network: ZcashNetwork

    static func make(
        alias: ZcashSynchronizerAlias = .default,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        callPrepareInConstructor: Bool = true
    ) -> TestCoordinator {
        var coordinator: TestCoordinator!
        XCTestCase.wait {
            coordinator = try await TestCoordinator(
                alias: alias,
                walletBirthday: walletBirthday,
                network: network,
                callPrepareInConstructor: callPrepareInConstructor
            )
        }
        return coordinator
    }

    static func make(
        alias: ZcashSynchronizerAlias = .default,
        spendingKey: UnifiedSpendingKey,
        unifiedFullViewingKey: UnifiedFullViewingKey,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        callPrepareInConstructor: Bool = true
    ) -> TestCoordinator {
        var coordinator: TestCoordinator!
        XCTestCase.wait {
            coordinator = try await TestCoordinator(
                alias: alias,
                spendingKey: spendingKey,
                unifiedFullViewingKey: unifiedFullViewingKey,
                walletBirthday: walletBirthday,
                network: network,
                callPrepareInConstructor: callPrepareInConstructor
            )
        }
        return coordinator
    }

    convenience init(
        alias: ZcashSynchronizerAlias = .default,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        callPrepareInConstructor: Bool = true
    ) async throws {
        let derivationTool = DerivationTool(networkType: network.networkType)

        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(
            seed: Environment.seedBytes,
            accountIndex: 0
        )

        let ufvk = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

        try await self.init(
            alias: alias,
            spendingKey: spendingKey,
            unifiedFullViewingKey: ufvk,
            walletBirthday: walletBirthday,
            network: network,
            callPrepareInConstructor: callPrepareInConstructor
        )
    }
    
    required init(
        alias: ZcashSynchronizerAlias = .default,
        spendingKey: UnifiedSpendingKey,
        unifiedFullViewingKey: UnifiedFullViewingKey,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        callPrepareInConstructor: Bool = true
    ) async throws {
        await InternalSyncProgress(alias: alias, storage: UserDefaults.standard, logger: logger).rewind(to: 0)

        self.spendingKey = spendingKey
        self.viewingKey = unifiedFullViewingKey
        self.birthday = walletBirthday
        self.databases = TemporaryDbBuilder.build()
        self.network = network

        let endpoint = LightWalletEndpoint(
            address: Constants.address,
            port: 9067,
            secure: false,
            singleCallTimeoutInMillis: 10000,
            streamingCallTimeoutInMillis: 1000000
        )
        let liveService = LightWalletServiceFactory(endpoint: endpoint).make()
        self.service = DarksideWalletService(service: liveService)

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: self.databases.fsCacheDbRoot,
            metadataStore: .live(
                fsBlockDbRoot: self.databases.fsCacheDbRoot,
                rustBackend: ZcashRustBackend.self,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        let synchronizer = TestSynchronizerBuilder.build(
            alias: alias,
            rustBackend: realRustBackend,
            fsBlockDbRoot: databases.fsCacheDbRoot,
            dataDbURL: databases.dataDB,
            pendingDbURL: databases.pendingDB,
            endpoint: LightWalletEndpointBuilder.default,
            service: self.service,
            repository: TransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: databases.dataDB.absoluteString)),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: databases.dataDB,
                readOnly: true,
                logger: logger
            ),
            storage: storage,
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            network: network,
            logLevel: .debug
        )
        
        self.synchronizer = synchronizer
        subscribeToState(synchronizer: self.synchronizer)

        if callPrepareInConstructor {
            if case .seedRequired = try await prepare(seed: Environment.seedBytes) {
                throw TestCoordinator.CoordinatorError.seedRequiredForMigration
            }
        }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables = []
    }

    func prepare(seed: [UInt8]) async throws -> Initializer.InitializationResult {
        return try await synchronizer.prepare(with: seed, viewingKeys: [viewingKey], walletBirthday: self.birthday)
    }
    
    func stop() async throws {
        await synchronizer.stop()
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
    
    func sync(completion: @escaping (SDKSynchronizer) throws -> Void, error: @escaping (Error?) async -> Void) async throws {
        self.completionHandler = completion
        self.errorHandler = error
        
        try await synchronizer.start(retry: true)
    }
    
    // MARK: notifications

    func subscribeToState(synchronizer: Synchronizer) {
        synchronizer.stateStream
            .sink(
                receiveValue: { [weak self] state in
                    switch state.syncStatus {
                    case let .error(error):
                        self?.synchronizerFailed(error: error)
                    case .synced:
                        try! self?.synchronizerSynced()
                    default:
                        break
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func synchronizerFailed(error: Error) {
        Task {
            await self.errorHandler?(error)
        }
    }
    
    func synchronizerSynced() throws {
        if case .stopped = self.synchronizer.latestState.syncStatus {
            LoggerProxy.debug("WARNING: notification received after synchronizer was stopped")
            return
        }
        try self.completionHandler?(self.synchronizer)
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
    
    func latestHeight() async throws -> BlockHeight {
        try await service.latestBlockHeight()
    }
    
    func reset(saplingActivation: BlockHeight, branchID: String, chainName: String) throws {
        Task {
            await self.synchronizer.blockProcessor.stop()
            let config = await self.synchronizer.blockProcessor.config

            let newConfig = CompactBlockProcessor.Configuration(
                alias: config.alias,
                fsBlockCacheRoot: config.fsBlockCacheRoot,
                dataDb: config.dataDb,
                spendParamsURL: config.spendParamsURL,
                outputParamsURL: config.outputParamsURL,
                saplingParamsSourceURL: config.saplingParamsSourceURL,
                downloadBatchSize: config.downloadBatchSize,
                retries: config.retries,
                maxBackoffInterval: config.maxBackoffInterval,
                rewindDistance: config.rewindDistance,
                walletBirthdayProvider: config.walletBirthdayProvider,
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
    var fsCacheDbRoot: URL
    var dataDB: URL
    var pendingDB: URL
}

enum TemporaryDbBuilder {
    static func build() -> TemporaryTestDatabases {
        let tempUrl = try! __documentsDirectory()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        return TemporaryTestDatabases(
            fsCacheDbRoot: tempUrl.appendingPathComponent("fs_cache_\(timestamp)"),
            dataDB: tempUrl.appendingPathComponent("data_db_\(timestamp).db"),
            pendingDB: tempUrl.appendingPathComponent("pending_db_\(timestamp).db")
        )
    }
}

enum TestSynchronizerBuilder {
    static func build(
        alias: ZcashSynchronizerAlias = .default,
        rustBackend: ZcashRustBackendWelding.Type,
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        accountRepository: AccountRepository,
        storage: CompactBlockRepository,
        spendParamsURL: URL,
        outputParamsURL: URL,
        network: ZcashNetwork,
        logLevel: OSLogger.LogLevel
    ) -> SDKSynchronizer {
        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            network: network,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            alias: alias,
            logLevel: logLevel
        )

        return SDKSynchronizer(initializer: initializer)
    }
}

extension TestCoordinator {
    static func loadResource(name: String, extension: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: `extension`)!
        return try! Data(contentsOf: url)
    }
}
