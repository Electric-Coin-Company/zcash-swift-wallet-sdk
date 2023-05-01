//
//  BlockBatchValidationTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 6/17/21.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class BlockBatchValidationTests: ZcashTestCase {
    let testFileManager = FileManager()
    var rustBackend: ZcashRustBackendWelding!
    var testTempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testTempDirectory = Environment.uniqueTestTempDirectory

        Dependencies.setup(
            in: mockContainer,
            urls: Initializer.URLs(
                fsBlockDbRoot: testTempDirectory,
                dataDbURL: try! __dataDbURL(),
                spendParamsURL: try! __spendParamsURL(),
                outputParamsURL: try! __outputParamsURL()
            ),
            alias: .default,
            networkType: .testnet,
            endpoint: LightWalletEndpointBuilder.default,
            loggingPolicy: .default(.debug)
        )

        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in LatestBlocksDataProviderMock() }

        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)
        rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: .testnet)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
        rustBackend = nil
        testTempDirectory = nil
    }

    func testBranchIdFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )
        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in storage }

        try await storage.create()

        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in
            let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
            return BlockDownloaderServiceImpl(service: service, storage: repository)
        }

        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { 1210000 },
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

        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: Int32(0xd34d))
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in mockBackend.rustBackendMock }
        
        let compactBlockProcessor = CompactBlockProcessor(
            container: mockContainer,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: mockContainer.resolve(BlockDownloaderService.self))
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case ZcashError.compactBlockProcessorWrongConsensusBranchId:
                break
            default:
                XCTFail("Expected ZcashError.compactBlockProcessorWrongConsensusBranchId but found \(error)")
            }
        }
    }
    
    func testBranchNetworkMismatchFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )
        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in storage }

        try await storage.create()

        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in
            let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
            return BlockDownloaderServiceImpl(service: service, storage: repository)
        }

        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { 1210000 },
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

        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in mockBackend.rustBackendMock }
        
        let compactBlockProcessor = CompactBlockProcessor(
            container: mockContainer,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: mockContainer.resolve(BlockDownloaderService.self))
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case ZcashError.compactBlockProcessorNetworkMismatch(.mainnet, .testnet):
                break
            default:
                XCTFail("Expected ZcashError.compactBlockProcessorNetworkMismatch but found \(error)")
            }
        }
    }
    
    func testBranchNetworkTypeWrongFailure() async throws {
        let network = ZcashNetworkBuilder.network(for: .testnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )
        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in storage }

        try await storage.create()

        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in
            let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
            return BlockDownloaderServiceImpl(service: service, storage: repository)
        }

        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { 1210000 },
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
        
        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in mockBackend.rustBackendMock }
        
        let compactBlockProcessor = CompactBlockProcessor(
            container: mockContainer,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: mockContainer.resolve(BlockDownloaderService.self))
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case ZcashError.compactBlockProcessorChainName:
                break
            default:
                XCTFail("Expected ZcashError.compactBlockProcessorChainName but found \(error)")
            }
        }
    }
    
    func testSaplingActivationHeightMismatch() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )
        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in storage }

        try await storage.create()

        mockContainer.mock(type: BlockDownloaderService.self, isSingleton: true) { _ in
            let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
            return BlockDownloaderServiceImpl(service: service, storage: repository)
        }

        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { 1210000 },
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
        
        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in mockBackend.rustBackendMock }
        
        let compactBlockProcessor = CompactBlockProcessor(
            container: mockContainer,
            config: config
        )
        
        do {
            try await compactBlockProcessor.figureNextBatch(downloaderService: mockContainer.resolve(BlockDownloaderService.self))
            XCTAssertFalse(Task.isCancelled)
        } catch {
            switch error {
            case ZcashError.compactBlockProcessorSaplingActivationMismatch(
                network.constants.saplingActivationHeight,
                BlockHeight(info.saplingActivationHeight)
            ):
                break
            default:
                XCTFail("Expected ZcashError.compactBlockProcessorSaplingActivationMismatch but found \(error)")
            }
        }
    }
    
    func testResultIsWait() async throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        
        let expectedLatestHeight = BlockHeight(1210000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        let expectedStoredLatestHeight = BlockHeight(1220000)
        let expectedResult = CompactBlockProcessor.NextState.wait(
            latestHeight: expectedLatestHeight,
            latestDownloadHeight: expectedStoredLatestHeight
        )

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoredLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)

        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { 1210000 },
            saplingActivation: network.constants.saplingActivationHeight,
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

        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)

        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextState(
                service: service,
                downloaderService: downloaderService,
                latestBlocksDataProvider: LatestBlocksDataProviderMock(
                    latestScannedHeight: expectedStoredLatestHeight,
                    latestBlockHeight: expectedLatestHeight
                ),
                config: config,
                rustBackend: mockBackend.rustBackendMock,
                internalSyncProgress: InternalSyncProgress(
                    alias: .default,
                    storage: InternalSyncProgressMemoryStorage(),
                    logger: logger
                )
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
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        let expectedStoredLatestHeight = BlockHeight(1220000)
        let walletBirthday = BlockHeight(1210000)

        let ranges = SyncRanges(
            latestBlockHeight: expectedLatestHeight,
            downloadedButUnscannedRange: nil,
            downloadAndScanRange: expectedStoredLatestHeight + 1...expectedLatestHeight,
            enhanceRange: walletBirthday...expectedLatestHeight,
            fetchUTXORange: walletBirthday...expectedLatestHeight,
            latestScannedHeight: expectedStoredLatestHeight,
            latestDownloadedBlockHeight: expectedStoredLatestHeight
        )
        let expectedResult = CompactBlockProcessor.NextState.processNewBlocks(ranges: ranges)

        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoredLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { walletBirthday },
            saplingActivation: network.constants.saplingActivationHeight,
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
        
        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)
        
        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextState(
                service: service,
                downloaderService: downloaderService,
                latestBlocksDataProvider: LatestBlocksDataProviderMock(
                    latestScannedHeight: expectedStoredLatestHeight,
                    latestBlockHeight: expectedLatestHeight
                ),
                config: config,
                rustBackend: mockBackend.rustBackendMock,
                internalSyncProgress: InternalSyncProgress(
                    alias: .default,
                    storage: InternalSyncProgressMemoryStorage(),
                    logger: logger
                )
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
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.default).make()
        )
        let expectedStoredLatestHeight = BlockHeight(1230000)
        let walletBirthday = BlockHeight(1210000)
        let expectedResult = CompactBlockProcessor.NextState.finishProcessing(height: expectedStoredLatestHeight)
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoredLatestHeight)
        let downloaderService = BlockDownloaderServiceImpl(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: try! __dataDbURL(),
            spendParamsURL: try! __spendParamsURL(),
            outputParamsURL: try! __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthdayProvider: { walletBirthday },
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        let internalSyncProgress = InternalSyncProgress(
            alias: .default,
            storage: InternalSyncProgressMemoryStorage(),
            logger: logger
        )
        await internalSyncProgress.set(expectedStoredLatestHeight, .latestEnhancedHeight)
        await internalSyncProgress.set(expectedStoredLatestHeight, .latestUTXOFetchedHeight)

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockBackend = await RustBackendMockHelper(rustBackend: rustBackend, consensusBranchID: 0xd34db4d)
        
        var nextBatch: CompactBlockProcessor.NextState?
        do {
            nextBatch = try await CompactBlockProcessor.NextStateHelper.nextState(
                service: service,
                downloaderService: downloaderService,
                latestBlocksDataProvider: LatestBlocksDataProviderMock(
                    latestScannedHeight: expectedStoredLatestHeight,
                    latestBlockHeight: expectedLatestHeight
                ),
                config: config,
                rustBackend: mockBackend.rustBackendMock,
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
