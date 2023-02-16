//
//  TransactionEnhancementTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/15/20.
//

import Combine
import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class TransactionEnhancementTests: XCTestCase {
    var cancellables: [AnyCancellable] = []
    var processorEventHandler: CompactBlockProcessorEventHandler! = CompactBlockProcessorEventHandler()
    let mockLatestHeight = BlockHeight(663250)
    let targetLatestHeight = BlockHeight(663251)
    let walletBirthday = BlockHeight(663150)
    let network = DarksideWalletDNetwork()
    let branchID = "2bb40e60"
    let chainName = "main"
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    var initializer: Initializer!
    var processorConfig: CompactBlockProcessor.Configuration!
    var processor: CompactBlockProcessor!
    var darksideWalletService: DarksideWalletService!
    var downloader: BlockDownloaderServiceImpl!
    var syncStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var finishedNotificationExpectation: XCTestExpectation!
    var reorgNotificationExpectation: XCTestExpectation!
    var afterReorgIdleNotification: XCTestExpectation!
    var txFoundNotificationExpectation: XCTestExpectation!
    var waitExpectation: XCTestExpectation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
        XCTestCase.wait { await InternalSyncProgress(storage: UserDefaults.standard).rewind(to: 0) }

        logger = OSLogger(logLevel: .debug)
        
        syncStartedExpect = XCTestExpectation(description: "\(self.description) syncStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: "\(self.description) stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: "\(self.description) updatedNotificationExpectation")
        finishedNotificationExpectation = XCTestExpectation(description: "\(self.description) finishedNotificationExpectation")
        afterReorgIdleNotification = XCTestExpectation(description: "\(self.description) afterReorgIdleNotification")
        reorgNotificationExpectation = XCTestExpectation(description: "\(self.description) reorgNotificationExpectation")
        txFoundNotificationExpectation = XCTestExpectation(description: "\(self.description) txFoundNotificationExpectation")
        
        waitExpectation = XCTestExpectation(description: "\(self.description) waitExpectation")

        let rustBackend = ZcashRustBackend.self
        let birthday = Checkpoint.birthday(with: walletBirthday, network: network)

        let pathProvider = DefaultResourceProvider(network: network)
        processorConfig = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: pathProvider.dataDbURL,
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
            walletBirthday: birthday.height,
            network: network
        )

        try? FileManager.default.removeItem(at: processorConfig.fsBlockCacheRoot)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)

        let dbInit = try rustBackend.initDataDb(dbData: processorConfig.dataDb, seed: nil, networkType: network.networkType)
        
        let ufvks = [
            try DerivationTool(networkType: network.networkType)
                .deriveUnifiedSpendingKey(seed: TestSeed().seed(), accountIndex: 0)
                .map {
                    try DerivationTool(networkType: network.networkType)
                        .deriveUnifiedFullViewingKey(from: $0)
                }
        ]
        do {
            try rustBackend.initAccountsTable(
                dbData: processorConfig.dataDb,
                ufvks: ufvks,
                networkType: network.networkType
            )
        } catch {
            XCTFail("Failed to init accounts table error: \(String(describing: rustBackend.getLastError()))")
            return
        }
        
        guard case .success = dbInit else {
            XCTFail("Failed to initDataDb. Expected `.success` got: \(String(describing: dbInit))")
            return
        }

        _ = try rustBackend.initBlocksTable(
            dbData: processorConfig.dataDb,
            height: Int32(birthday.height),
            hash: birthday.hash,
            time: birthday.time,
            saplingTree: birthday.saplingTree,
            networkType: network.networkType
        )
        
        let service = DarksideWalletService()
        darksideWalletService = service
        
        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )
        try! storage.create()
        
        downloader = BlockDownloaderServiceImpl(service: service, storage: storage)
        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: rustBackend,
            config: processorConfig
        )

        var stream: AnyPublisher<CompactBlockProcessor.Event, Never>!
        XCTestCase.wait { await stream = self.processor.eventStream }
        stream
            .sink { [weak self] event in
                switch event {
                case .failed: self?.processorFailed(event: event)
                default: break
                }
            }
            .store(in: &cancellables)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        XCTestCase.wait { await self.processor.stop() }
        try? FileManager.default.removeItem(at: processorConfig.fsBlockCacheRoot)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        NotificationCenter.default.removeObserver(self)
        processorEventHandler = nil
        initializer = nil
        processorConfig = nil
        processor = nil
        darksideWalletService = nil
        downloader = nil
    }
    
    private func startProcessing() async throws {
        XCTAssertNotNil(processor)

        let expectations: [CompactBlockProcessorEventHandler.EventIdentifier: XCTestExpectation] = [
            .startedSyncing: syncStartedExpect,
            .stopped: stopNotificationExpectation,
            .progressUpdated: updatedNotificationExpectation,
            .foundTransactions: txFoundNotificationExpectation,
            .finished: finishedNotificationExpectation
        ]
        processorEventHandler.subscribe(to: await processor.eventStream, expectations: expectations)

        await processor.start()
    }
    
    func testBasicEnhancement() async throws {
        let targetLatestHeight = BlockHeight(663200)
        
        do {
            try FakeChainBuilder.buildChain(darksideWallet: darksideWalletService, branchID: branchID, chainName: chainName)

            try darksideWalletService.applyStaged(nextLatestHeight: targetLatestHeight)
        } catch {
            XCTFail("Error: \(error)")
            return
        }

        sleep(3)

        /**
        connect to dLWD
        request latest height -> receive firstLatestHeight
        */
        do {
            dump("first latest height:  \(try darksideWalletService.latestBlockHeight())")
        } catch {
            XCTFail("Error: \(error)")
            return
        }

        /**
        download and sync blocks from walletBirthday to firstLatestHeight
        */
        do {
            try await startProcessing()
        } catch {
            XCTFail("Error: \(error)")
        }

        wait(
            for: [
                syncStartedExpect,
                txFoundNotificationExpectation,
                finishedNotificationExpectation
            ],
            timeout: 30
        )
    }
    
    func processorFailed(event: CompactBlockProcessor.Event) {
        if case let .failed(error) = event {
            XCTFail("CompactBlockProcessor failed with Error: \(error)")
        } else {
            XCTFail("CompactBlockProcessor failed")
        }
    }
}
