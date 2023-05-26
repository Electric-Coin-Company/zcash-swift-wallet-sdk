//
//  CompactBlockProcessorTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 20/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class CompactBlockProcessorTests: ZcashTestCase {
    var processorConfig: CompactBlockProcessor.Configuration!
    var cancellables: [AnyCancellable] = []
    var processorEventHandler: CompactBlockProcessorEventHandler! = CompactBlockProcessorEventHandler()
    var rustBackend: ZcashRustBackendWelding!
    var processor: CompactBlockProcessor!
    var syncStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var finishedNotificationExpectation: XCTestExpectation!
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let mockLatestHeight = ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight + 2000

    let testFileManager = FileManager()

    override func setUp() async throws {
        try await super.setUp()
        logger = OSLogger(logLevel: .debug)

        for key in InternalSyncProgress.Key.allCases {
            UserDefaults.standard.set(0, forKey: key.with(.default))
        }

        let pathProvider = DefaultResourceProvider(network: network)
        processorConfig = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: pathProvider.dataDbURL,
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight },
            network: ZcashNetworkBuilder.network(for: .testnet)
        )

        let liveService = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        let service = MockLightWalletService(
            latestBlockHeight: mockLatestHeight,
            service: liveService
        )

        rustBackend = ZcashRustBackend.makeForTests(
            dbData: processorConfig.dataDb,
            fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
            networkType: network.networkType
        )

        let branchID = try rustBackend.consensusBranchIdFor(height: Int32(mockLatestHeight))
        service.mockLightDInfo = LightdInfo.with({ info in
            info.blockHeight = UInt64(mockLatestHeight)
            info.branch = "asdf"
            info.buildDate = "today"
            info.buildUser = "testUser"
            info.chainName = "test"
            info.consensusBranchID = branchID.toString()
            info.estimatedHeight = UInt64(mockLatestHeight)
            info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        })
        
        let transactionRepository = MockTransactionRepository(
            unminedCount: 0,
            receivedCount: 0,
            sentCount: 0,
            scannedHeight: 0,
            network: network
        )
        
        Dependencies.setup(
            in: mockContainer,
            urls: Initializer.URLs(
                fsBlockDbRoot: testTempDirectory,
                dataDbURL: processorConfig.dataDb,
                generalStorageURL: testGeneralStorageDirectory,
                spendParamsURL: processorConfig.spendParamsURL,
                outputParamsURL: processorConfig.outputParamsURL
            ),
            alias: .default,
            networkType: .testnet,
            endpoint: LightWalletEndpointBuilder.default,
            loggingPolicy: .default(.debug)
        )
        
        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in
            LatestBlocksDataProviderImpl(service: service, transactionRepository: transactionRepository)
        }
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in self.rustBackend }
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }
        try await mockContainer.resolve(CompactBlockRepository.self).create()
        
        processor = CompactBlockProcessor(container: mockContainer, config: processorConfig)

        let dbInit = try await rustBackend.initDataDb(seed: nil)

        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(dbInit)")
            return
        }
        
        syncStartedExpect = XCTestExpectation(description: "\(self.description) syncStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: "\(self.description) stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: "\(self.description) updatedNotificationExpectation")
        finishedNotificationExpectation = XCTestExpectation(description: "\(self.description) finishedNotificationExpectation")

        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case .failed: self?.processorFailed(event: event)
            default: break
            }
        }

        await self.processor.updateEventClosure(identifier: "tests", closure: eventClosure)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await processor.stop()
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        cancellables = []
        processor = nil
        processorEventHandler = nil
        rustBackend = nil
        testTempDirectory = nil
    }
    
    func processorFailed(event: CompactBlockProcessor.Event) {
        if case let .failed(error) = event {
            XCTFail("CompactBlockProcessor failed with Error: \(error)")
        } else {
            XCTFail("CompactBlockProcessor failed")
        }
    }
    
    private func startProcessing() async {
        XCTAssertNotNil(processor)

        let expectations: [CompactBlockProcessorEventHandler.EventIdentifier: XCTestExpectation] = [
            .startedSyncing: syncStartedExpect,
            .stopped: stopNotificationExpectation,
            .progressUpdated: updatedNotificationExpectation,
            .finished: finishedNotificationExpectation
        ]

        await processorEventHandler.subscribe(to: processor, expectations: expectations)
        await processor.start()
    }

    func testStartNotifiesSuscriptors() async {
        await startProcessing()
   
        await fulfillment(
            of: [
                syncStartedExpect,
                finishedNotificationExpectation
            ],
            timeout: 30,
            enforceOrder: false
        )
    }

    func testProgressNotifications() async {
        let expectedUpdates = expectedBatches(
            currentHeight: processorConfig.walletBirthday,
            targetHeight: mockLatestHeight,
            batchSize: processorConfig.batchSize
        )
        updatedNotificationExpectation.expectedFulfillmentCount = expectedUpdates
        
        await startProcessing()
        await fulfillment(of: [updatedNotificationExpectation, finishedNotificationExpectation], timeout: 300)
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight - targetHeight) / batchSize)
    }
    
    func testNextBatchBlockRange() async throws {
        // test first range
        var latestDownloadedHeight = processorConfig.walletBirthday // this can be either this or Wallet Birthday.
        var latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)
        
        var expectedSyncRanges = SyncRanges(
            latestBlockHeight: latestBlockchainHeight,
            downloadRange: latestDownloadedHeight...latestBlockchainHeight,
            scanRange: latestDownloadedHeight...latestBlockchainHeight,
            enhanceRange: processorConfig.walletBirthday...latestBlockchainHeight,
            fetchUTXORange: processorConfig.walletBirthday...latestBlockchainHeight,
            latestScannedHeight: 0,
            latestDownloadedBlockHeight: latestDownloadedHeight
        )

        var internalSyncProgress = InternalSyncProgress(
            alias: .default,
            storage: InternalSyncProgressMemoryStorage(),
            logger: logger
        )
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight, alias: .default)

        var syncRanges = try await internalSyncProgress.computeSyncRanges(
            birthday: processorConfig.walletBirthday,
            latestBlockHeight: latestBlockchainHeight,
            latestScannedHeight: 0
        )

        XCTAssertEqual(
            expectedSyncRanges,
            syncRanges,
            "Failure when testing first range"
        )

        // Test mid-range
        latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight + ZcashSDK.DefaultBatchSize)
        latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        expectedSyncRanges = SyncRanges(
            latestBlockHeight: latestBlockchainHeight,
            downloadRange: latestDownloadedHeight + 1...latestBlockchainHeight,
            scanRange: processorConfig.walletBirthday...latestBlockchainHeight,
            enhanceRange: processorConfig.walletBirthday...latestBlockchainHeight,
            fetchUTXORange: processorConfig.walletBirthday...latestBlockchainHeight,
            latestScannedHeight: 0,
            latestDownloadedBlockHeight: latestDownloadedHeight
        )

        internalSyncProgress = InternalSyncProgress(
            alias: .default,
            storage: InternalSyncProgressMemoryStorage(),
            logger: logger
        )
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight, alias: .default)

        syncRanges = try await internalSyncProgress.computeSyncRanges(
            birthday: processorConfig.walletBirthday,
            latestBlockHeight: latestBlockchainHeight,
            latestScannedHeight: 0
        )
        
        XCTAssertEqual(
            expectedSyncRanges,
            syncRanges,
            "Failure when testing mid range"
        )
        
        // Test last batch range
        
        latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight + 950)
        latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        expectedSyncRanges = SyncRanges(
            latestBlockHeight: latestBlockchainHeight,
            downloadRange: latestDownloadedHeight + 1...latestBlockchainHeight,
            scanRange: processorConfig.walletBirthday...latestBlockchainHeight,
            enhanceRange: processorConfig.walletBirthday...latestBlockchainHeight,
            fetchUTXORange: processorConfig.walletBirthday...latestBlockchainHeight,
            latestScannedHeight: 0,
            latestDownloadedBlockHeight: latestDownloadedHeight
        )

        internalSyncProgress = InternalSyncProgress(
            alias: .default,
            storage: InternalSyncProgressMemoryStorage(),
            logger: logger
        )
        try await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight, alias: .default)

        syncRanges = try await internalSyncProgress.computeSyncRanges(
            birthday: processorConfig.walletBirthday,
            latestBlockHeight: latestBlockchainHeight,
            latestScannedHeight: 0
        )
        
        XCTAssertEqual(
            expectedSyncRanges,
            syncRanges,
            "Failure when testing last range"
        )
    }
    
    func testDetermineLowerBoundPastBirthday() async {
        let errorHeight = 781_906
        
        let walletBirthday = 781_900
        
        let result = await processor.determineLowerBound(errorHeight: errorHeight, consecutiveErrors: 1, walletBirthday: walletBirthday)
        let expected = 781_886
        
        XCTAssertEqual(result, expected)
    }
    
    func testDetermineLowerBound() async {
        let errorHeight = 781_906
        
        let walletBirthday = 780_900
        
        let result = await processor.determineLowerBound(errorHeight: errorHeight, consecutiveErrors: 0, walletBirthday: walletBirthday)
        let expected = 781_896
        
        XCTAssertEqual(result, expected)
    }
}
