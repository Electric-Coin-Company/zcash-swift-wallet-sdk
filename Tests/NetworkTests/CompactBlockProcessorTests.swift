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

class CompactBlockProcessorTests: XCTestCase {
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
    var testTempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        logger = OSLogger(logLevel: .debug)
        testTempDirectory = Environment.uniqueTestTempDirectory

        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)

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

        await InternalSyncProgress(
            alias: .default,
            storage: UserDefaults.standard,
            logger: logger
        ).rewind(to: 0)

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

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await storage.create()
        
        let transactionRepository = MockTransactionRepository(
            unminedCount: 0,
            receivedCount: 0,
            sentCount: 0,
            scannedHeight: 0,
            network: network
        )
        
        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            rustBackend: rustBackend,
            config: processorConfig,
            metrics: SDKMetrics(),
            logger: logger,
            latestBlocksDataProvider: LatestBlocksDataProviderImpl(service: service, transactionRepository: transactionRepository)
        )

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
        await self.processor.stop()
        try FileManager.default.removeItem(at: processorConfig.fsBlockCacheRoot)
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
            batchSize: processorConfig.downloadBatchSize
        )
        updatedNotificationExpectation.expectedFulfillmentCount = expectedUpdates
        
        await startProcessing()
        await fulfillment(of: [updatedNotificationExpectation, finishedNotificationExpectation], timeout: 300)
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight - targetHeight) / batchSize)
    }
    
    func testNextBatchBlockRange() async {
        // test first range
        var latestDownloadedHeight = processorConfig.walletBirthday // this can be either this or Wallet Birthday.
        var latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)
        
        var expectedSyncRanges = SyncRanges(
            latestBlockHeight: latestBlockchainHeight,
            downloadedButUnscannedRange: 1...latestDownloadedHeight,
            downloadAndScanRange: latestDownloadedHeight...latestBlockchainHeight,
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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight)

        var syncRanges = await internalSyncProgress.computeSyncRanges(
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
        latestDownloadedHeight = BlockHeight(network.constants.saplingActivationHeight + ZcashSDK.DefaultDownloadBatch)
        latestBlockchainHeight = BlockHeight(network.constants.saplingActivationHeight + 1000)

        expectedSyncRanges = SyncRanges(
            latestBlockHeight: latestBlockchainHeight,
            downloadedButUnscannedRange: 1...latestDownloadedHeight,
            downloadAndScanRange: latestDownloadedHeight + 1...latestBlockchainHeight,
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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight)

        syncRanges = await internalSyncProgress.computeSyncRanges(
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
            downloadedButUnscannedRange: 1...latestDownloadedHeight,
            downloadAndScanRange: latestDownloadedHeight + 1...latestBlockchainHeight,
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
        await internalSyncProgress.migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB: latestDownloadedHeight)

        syncRanges = await internalSyncProgress.computeSyncRanges(
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

    func testShouldClearBlockCacheReturnsNilWhenScannedHeightEqualsDownloadedHeight() {
        /*
         downloaded but not scanned: -1...-1
         download and scan:          1493120...2255953
         enhance range:              1410000...2255953
         fetchUTXO range:            1410000...2255953
         total progress range:       1493120...2255953
         */

        let range = SyncRanges(
            latestBlockHeight: 2255953,
            downloadedButUnscannedRange: -1 ... -1,
            downloadAndScanRange: 1493120...2255953,
            enhanceRange: 1410000...2255953,
            fetchUTXORange: 1410000...2255953,
            latestScannedHeight: 1493119,
            latestDownloadedBlockHeight: 1493119
        )

        XCTAssertNil(range.shouldClearBlockCacheAndUpdateInternalState())
    }

    func testShouldClearBlockCacheReturnsAHeightWhenScannedIsGreaterThanDownloaded() {
        /*
         downloaded but not scanned: -1...-1
         download and scan:          1493120...2255953
         enhance range:              1410000...2255953
         fetchUTXO range:            1410000...2255953
         total progress range:       1493120...2255953
         */

        let range = SyncRanges(
            latestBlockHeight: 2255953,
            downloadedButUnscannedRange: -1 ... -1,
            downloadAndScanRange: 1493120...2255953,
            enhanceRange: 1410000...2255953,
            fetchUTXORange: 1410000...2255953,
            latestScannedHeight: 1493129,
            latestDownloadedBlockHeight: 1493119
        )

        XCTAssertEqual(range.shouldClearBlockCacheAndUpdateInternalState(), BlockHeight(1493129))
    }

    func testShouldClearBlockCacheReturnsNilWhenScannedIsGreaterThanDownloaded() {
        /*
         downloaded but not scanned: 1493120...1494120
         download and scan:          1494121...2255953
         enhance range:              1410000...2255953
         fetchUTXO range:            1410000...2255953
         total progress range:       1493120...2255953
         */

        let range = SyncRanges(
            latestBlockHeight: 2255953,
            downloadedButUnscannedRange: 1493120...1494120,
            downloadAndScanRange: 1494121...2255953,
            enhanceRange: 1410000...2255953,
            fetchUTXORange: 1410000...2255953,
            latestScannedHeight: 1493119,
            latestDownloadedBlockHeight: 1494120
        )

        XCTAssertNil(range.shouldClearBlockCacheAndUpdateInternalState())
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
