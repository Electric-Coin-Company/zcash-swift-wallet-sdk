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
    lazy var processorConfig = {
        let pathProvider = DefaultResourceProvider(network: network)
        return CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: pathProvider.dataDbURL,
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight },
            network: ZcashNetworkBuilder.network(for: .testnet)
        )
    }()

    var cancellables: [AnyCancellable] = []
    var processorEventHandler: CompactBlockProcessorEventHandler! = CompactBlockProcessorEventHandler()
    var processor: CompactBlockProcessor!
    var syncStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var finishedNotificationExpectation: XCTestExpectation!
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let mockLatestHeight = ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight + 2000
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = OSLogger(logLevel: .debug)
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)

        XCTestCase.wait { await InternalSyncProgress(alias: .default, storage: UserDefaults.standard).rewind(to: 0) }

        let liveService = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        let service = MockLightWalletService(
            latestBlockHeight: mockLatestHeight,
            service: liveService
        )
        let branchID = try ZcashRustBackend.consensusBranchIdFor(height: Int32(mockLatestHeight), networkType: network.networkType)
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

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()
        
        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: realRustBackend,
            config: processorConfig,
            metrics: SDKMetrics()
        )

        let dbInit = try realRustBackend.initDataDb(dbData: processorConfig.dataDb, seed: nil, networkType: .testnet)

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

        XCTestCase.wait { await self.processor.updateEventClosure(identifier: "tests", closure: eventClosure) }
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        XCTestCase.wait { await self.processor.stop() }
        try FileManager.default.removeItem(at: processorConfig.fsBlockCacheRoot)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        NotificationCenter.default.removeObserver(self)
        cancellables = []
        processor = nil
        processorEventHandler = nil
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
   
        wait(
            for: [
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
        wait(for: [updatedNotificationExpectation, finishedNotificationExpectation], timeout: 300)
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

        var internalSyncProgress = InternalSyncProgress(alias: .default, storage: InternalSyncProgressMemoryStorage())
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

        internalSyncProgress = InternalSyncProgress(alias: .default, storage: InternalSyncProgressMemoryStorage())
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

        internalSyncProgress = InternalSyncProgress(alias: .default, storage: InternalSyncProgressMemoryStorage())
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
