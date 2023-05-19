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
    var completionHandler: ((SDKSynchronizer) async throws -> Void)?
    var errorHandler: ((Error?) async -> Void)?
    var spendingKey: UnifiedSpendingKey
    let viewingKey: UnifiedFullViewingKey
    var birthday: BlockHeight
    var synchronizer: SDKSynchronizer
    var service: DarksideWalletService
    var databases: TemporaryTestDatabases
    let network: ZcashNetwork

    static let defaultEndpoint = LightWalletEndpoint(
        address: Constants.address,
        port: 9067,
        secure: false,
        singleCallTimeoutInMillis: 10000,
        streamingCallTimeoutInMillis: 1000000
    )
    
    init(
        alias: ZcashSynchronizerAlias = .default,
        container: DIContainer,
        walletBirthday: BlockHeight,
        network: ZcashNetwork,
        callPrepareInConstructor: Bool = true,
        endpoint: LightWalletEndpoint = TestCoordinator.defaultEndpoint,
        syncSessionIDGenerator: SyncSessionIDGenerator = UniqueSyncSessionIDGenerator(),
        dbTracingClosure: ((String) -> Void)? = nil
    ) async throws {
        let databases = TemporaryDbBuilder.build()
        self.databases = databases

        let storage = InternalSyncProgressDiskStorage(storageURL: databases.generalStorageURL, logger: logger)
        let internalSyncProgress = InternalSyncProgress(alias: alias, storage: storage, logger: logger)
        try await internalSyncProgress.initialize()
        try await internalSyncProgress.rewind(to: 0)

        let initializer = Initializer(
            container: container,
            cacheDbURL: nil,
            fsBlockDbRoot: databases.fsCacheDbRoot,
            generalStorageURL: databases.generalStorageURL,
            dataDbURL: databases.dataDB,
            endpoint: endpoint,
            network: network,
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            alias: alias,
            loggingPolicy: .default(.debug)
        )

        let derivationTool = DerivationTool(networkType: network.networkType)
        
        self.spendingKey = try derivationTool.deriveUnifiedSpendingKey(
            seed: Environment.seedBytes,
            accountIndex: 0
        )
        
        self.viewingKey = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)
        self.birthday = walletBirthday
        self.network = network
        
        let liveService = LightWalletServiceFactory(endpoint: endpoint).make()
        self.service = DarksideWalletService(endpoint: endpoint, service: liveService)
        self.synchronizer = SDKSynchronizer(initializer: initializer)
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
        await synchronizer.blockProcessor.stop()
        completionHandler = nil
        errorHandler = nil
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
    
    func sync(completion: @escaping (SDKSynchronizer) async throws -> Void, error: @escaping (Error?) async -> Void) async throws {
        self.completionHandler = completion
        self.errorHandler = error
        
        try await synchronizer.start(retry: true)
    }
    
    // MARK: notifications
    func subscribeToState(synchronizer: Synchronizer) {
        synchronizer.stateStream
            .sink(
                receiveValue: { [weak self] state in
                    switch state.internalSyncStatus {
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
        Task(priority: .high) {
            await self.errorHandler?(error)
        }
    }
    
    func synchronizerSynced() throws {
        if case .stopped = self.synchronizer.latestState.internalSyncStatus {
            LoggerProxy.debug("WARNING: notification received after synchronizer was stopped")
            return
        }
        Task(priority: .high) {
            try await self.completionHandler?(self.synchronizer)
        }
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
        try service.stageBlocksCreate(from: height, count: count, nonce: nonce)
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
            // TODO: [#1102] review and potentially fix/remove commented code https://github.com/zcash/ZcashLightClientKit/issues/1102
//            let config = await self.synchronizer.blockProcessor.config
//
//            let newConfig = CompactBlockProcessor.Configuration(
//                alias: config.alias,
//                fsBlockCacheRoot: config.fsBlockCacheRoot,
//                dataDb: config.dataDb,
//                spendParamsURL: config.spendParamsURL,
//                outputParamsURL: config.outputParamsURL,
//                saplingParamsSourceURL: config.saplingParamsSourceURL,
//                retries: config.retries,
//                maxBackoffInterval: config.maxBackoffInterval,
//                rewindDistance: config.rewindDistance,
//                walletBirthdayProvider: config.walletBirthdayProvider,
//                saplingActivation: saplingActivation,
//                network: config.network
//            )

//            await self.synchronizer.blockProcessor.update(config: newConfig)
        }

        try service.reset(saplingActivation: saplingActivation, branchID: branchID, chainName: chainName)
    }
    
    func getIncomingTransactions() throws -> [RawTransaction]? {
        return try service.getIncomingTransactions()
    }
}

struct TemporaryTestDatabases {
    var fsCacheDbRoot: URL
    let generalStorageURL: URL
    var dataDB: URL
}

enum TemporaryDbBuilder {
    static func build() -> TemporaryTestDatabases {
        let tempUrl = try! __documentsDirectory()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        return TemporaryTestDatabases(
            fsCacheDbRoot: tempUrl.appendingPathComponent("fs_cache_\(timestamp)"),
            generalStorageURL: tempUrl.appendingPathComponent("general_storage_\(timestamp)"),
            dataDB: tempUrl.appendingPathComponent("data_db_\(timestamp).db")
        )
    }
}

extension TestCoordinator {
    static func loadResource(name: String, extension: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: `extension`)!
        return try! Data(contentsOf: url)
    }
}
