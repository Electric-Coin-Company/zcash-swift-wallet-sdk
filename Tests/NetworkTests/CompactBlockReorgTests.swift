//
//  CompactBlockReorgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/13/19.
//
//  Copyright © 2019 Electric Coin Company. All rights reserved.

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class CompactBlockReorgTests: XCTestCase {
    lazy var processorConfig = {
        let pathProvider = DefaultResourceProvider(network: network)
        return CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: Environment.testTempDirectory,
            dataDb: pathProvider.dataDbURL,
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight },
            network: ZcashNetworkBuilder.network(for: .testnet)
        )
    }()

    let testFileManager = FileManager()
    var cancellables: [AnyCancellable] = []
    var processorEventHandler: CompactBlockProcessorEventHandler! = CompactBlockProcessorEventHandler()

    var processor: CompactBlockProcessor!
    var syncStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var finishedNotificationExpectation: XCTestExpectation!
    var reorgNotificationExpectation: XCTestExpectation!
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let mockLatestHeight = ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight + 2000

    override func setUp() async throws {
        try await super.setUp()
        logger = OSLogger(logLevel: .debug)
        try self.testFileManager.createDirectory(at: Environment.testTempDirectory, withIntermediateDirectories: false)

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
        
        let branchID = try ZcashRustBackend.consensusBranchIdFor(height: Int32(mockLatestHeight), networkType: network.networkType)
        service.mockLightDInfo = LightdInfo.with { info in
            info.blockHeight = UInt64(mockLatestHeight)
            info.branch = "asdf"
            info.buildDate = "today"
            info.buildUser = "testUser"
            info.chainName = "test"
            info.consensusBranchID = branchID.toString()
            info.estimatedHeight = UInt64(mockLatestHeight)
            info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        }

        let realRustBackend = ZcashRustBackend.self

        let realCache = FSCompactBlockRepository(
            fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: processorConfig.fsBlockCacheRoot,
                rustBackend: realRustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await realCache.create()

        let initResult = try await realRustBackend.initDataDb(dbData: processorConfig.dataDb, seed: nil, networkType: .testnet)
        guard case .success = initResult else {
            XCTFail("initDataDb failed. Expected Success but got .seedRequired")
            return
        }

        let mockBackend = MockRustBackend.self
        mockBackend.mockValidateCombinedChainFailAfterAttempts = 3
        mockBackend.mockValidateCombinedChainKeepFailing = false
        mockBackend.mockValidateCombinedChainFailureHeight = self.network.constants.saplingActivationHeight + 320
        
        processor = CompactBlockProcessor(
            service: service,
            storage: realCache,
            backend: mockBackend,
            config: processorConfig,
            metrics: SDKMetrics(),
            logger: logger
        )
        
        syncStartedExpect = XCTestExpectation(description: "\(self.description) syncStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: "\(self.description) stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: "\(self.description) updatedNotificationExpectation")
        finishedNotificationExpectation = XCTestExpectation(description: "\(self.description) finishedNotificationExpectation")
        reorgNotificationExpectation = XCTestExpectation(description: "\(self.description) reorgNotificationExpectation")

        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case .failed: self?.processorFailed(event: event)
            case .handledReorg: self?.processorHandledReorg(event: event)
            default: break
            }
        }

        await self.processor.updateEventClosure(identifier: "tests", closure: eventClosure)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await self.processor.stop()
        try! FileManager.default.removeItem(at: processorConfig.fsBlockCacheRoot)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        cancellables = []
        processorEventHandler = nil
        processor = nil
    }
    
    func processorHandledReorg(event: CompactBlockProcessor.Event) {
        if case let .handledReorg(reorg, rewind) = event {
            XCTAssertTrue( reorg == 0 || reorg > self.network.constants.saplingActivationHeight)
            XCTAssertTrue( rewind == 0 || rewind > self.network.constants.saplingActivationHeight)
            XCTAssertTrue( rewind <= reorg )
            reorgNotificationExpectation.fulfill()
        } else {
            XCTFail("CompactBlockProcessor reorg notification is malformed")
        }
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
            .finished: finishedNotificationExpectation,
            .handleReorg: reorgNotificationExpectation
        ]

        await processorEventHandler.subscribe(to: processor, expectations: expectations)
        await processor.start()
    }
    
    func testNotifiesReorg() async {
        await startProcessing()

        wait(
            for: [
                syncStartedExpect,
                reorgNotificationExpectation,
                finishedNotificationExpectation
            ],
            timeout: 300,
            enforceOrder: true
        )
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight - targetHeight) / batchSize)
    }
}
