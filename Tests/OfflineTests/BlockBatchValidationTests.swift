//
//  BlockBatchValidationTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 6/17/21.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class BlockBatchValidationTests: XCTestCase {
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
    }

    func testBranchIdFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db33f"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = Int32(0xd34d)
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: mockRust,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: downloaderService)
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case CompactBlockProcessorError.wrongConsensusBranchId:
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.wrongConsensusBranchId but found \(error)")
            }
        }
    }
    
    func testBranchNetworkMismatchFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )
        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "test"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: mockRust,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: downloaderService)
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case CompactBlockProcessorError.networkMismatch(expected: .mainnet, found: .testnet):
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.networkMismatch but found \(error)")
            }
        }
    }
    
    func testBranchNetworkTypeWrongFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .testnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )
        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "another"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: mockRust,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: downloaderService)
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case CompactBlockProcessorError.generalError:
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.generalError but found \(error)")
            }
        }
    }
    
    func testSaplingActivationHeightMismatch() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(3434343)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: mockRust,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: downloaderService)
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case CompactBlockProcessorError.saplingActivationMismatch(
                expected: network.constants.saplingActivationHeight,
                found: BlockHeight(info.saplingActivationHeight)
            ):
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.saplingActivationMismatch but found \(error)")
            }
        }
    }
    
    func testResultIsWait() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        
        let expectedLatestHeight = BlockHeight(1210000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )
        let expectedStoredLatestHeight = BlockHeight(1220000)
        let expectedResult = CompactBlockProcessor.NextState.wait(
            latestHeight: expectedLatestHeight,
            latestDownloadHeight: expectedStoredLatestHeight
        )

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoredLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)

        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        let transactionRepository = MockTransactionRepository(
            unminedCount: 0,
            receivedCount: 0,
            sentCount: 0,
            scannedHeight: expectedStoredLatestHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextStateAsync(
                service: service,
                downloaderService: downloaderService,
                transactionRepository: transactionRepository,
                config: config,
                rustBackend: mockRust,
                internalSyncProgress: InternalSyncProgress(storage: InternalSyncProgressMemoryStorage())
            )
            XCTAssertFalse(Task.isCancelled)
        } catch {
            XCTFail("this shouldn't happen: \(error)")
        }
        
        guard nextBatch != nil else {
            XCTFail("result should not be nil")
            return
        }
        
        XCTAssertTrue(
            {
                switch (nextBatch, expectedResult) {
                case let (.wait(latestHeight, latestDownloadHeight), .wait(expectedLatestHeight, exectedLatestDownloadHeight)):
                    return latestHeight == expectedLatestHeight && latestDownloadHeight == exectedLatestDownloadHeight
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(String(describing: nextBatch))"
        )
    }
    
    func testResultProcessNew() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let expectedLatestHeight = BlockHeight(1230000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )
        let expectedStoreLatestHeight = BlockHeight(1220000)
        let walletBirthday = BlockHeight(1210000)

        let ranges = SyncRanges(
            latestBlockHeight: expectedLatestHeight,
            downloadedButUnscannedRange: nil,
            downloadAndScanRange: expectedStoreLatestHeight + 1...expectedLatestHeight,
            enhanceRange: walletBirthday...expectedLatestHeight,
            fetchUTXORange: walletBirthday...expectedLatestHeight
        )
        let expectedResult = CompactBlockProcessor.NextState.processNewBlocks(ranges: ranges)

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoreLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: walletBirthday,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        let transactionRepository = MockTransactionRepository(
            unminedCount: 0,
            receivedCount: 0,
            sentCount: 0,
            scannedHeight: expectedStoreLatestHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d
        
        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextStateAsync(
                service: service,
                downloaderService: downloaderService,
                transactionRepository: transactionRepository,
                config: config,
                rustBackend: mockRust,
                internalSyncProgress: InternalSyncProgress(storage: InternalSyncProgressMemoryStorage())
            )
            XCTAssertFalse(Task.isCancelled)
        } catch {
            XCTFail("this shouldn't happen: \(error)")
        }
        
        guard nextBatch != nil else {
            XCTFail("result should not be nil")
            return
        }

        XCTAssertTrue(
            {
                switch (nextBatch, expectedResult) {
                case let (.processNewBlocks(ranges), .processNewBlocks(expectedRanges)):
                    return ranges == expectedRanges
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(String(describing: nextBatch))"
        )
    }
    
    func testResultProcessorFinished() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let expectedLatestHeight = BlockHeight(1230000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default, connectionStateChange: { _, _ in }).make()
        )
        let expectedStoreLatestHeight = BlockHeight(1230000)
        let walletBirthday = BlockHeight(1210000)
        let expectedResult = CompactBlockProcessor.NextState.finishProcessing(height: expectedStoreLatestHeight)
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoreLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: walletBirthday,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        let internalSyncProgress = InternalSyncProgress(storage: InternalSyncProgressMemoryStorage())
        await internalSyncProgress.set(expectedStoreLatestHeight, .latestEnhancedHeight)
        await internalSyncProgress.set(expectedStoreLatestHeight, .latestUTXOFetchedHeight)

        let transactionRepository = MockTransactionRepository(
            unminedCount: 0,
            receivedCount: 0,
            sentCount: 0,
            scannedHeight: expectedStoreLatestHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d
        
        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextStateAsync(
                service: service,
                downloaderService: downloaderService,
                transactionRepository: transactionRepository,
                config: config,
                rustBackend: mockRust,
                internalSyncProgress: internalSyncProgress
            )

            XCTAssertFalse(Task.isCancelled)
        } catch {
            XCTFail("this shouldn't happen: \(error)")
        }
        
        guard nextBatch != nil else {
            XCTFail("result should not be nil")
            return
        }
        
        XCTAssertTrue(
            {
                switch (nextBatch, expectedResult) {
                case let (.finishProcessing(height), .finishProcessing(expectedHeight)):
                    return height == expectedHeight
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(String(describing: nextBatch))"
        )
    }
}
