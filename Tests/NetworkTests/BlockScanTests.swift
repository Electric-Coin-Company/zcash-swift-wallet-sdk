//
//  BlockScanTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/17/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import XCTest
import SQLite
@testable import TestUtils
@testable import ZcashLightClientKit

class BlockScanTests: XCTestCase {
    var cancelables: [AnyCancellable] = []

    var dataDbURL: URL!
    var spendParamsURL: URL!
    var outputParamsURL: URL!
    // swiftlint:disable:next line_length
    var saplingExtendedKey = SaplingExtendedFullViewingKey(validatedEncoding: "zxviewtestsapling1qw88ayg8qqqqpqyhg7jnh9mlldejfqwu46pm40ruwstd8znq3v3l4hjf33qcu2a5e36katshcfhcxhzgyfugj2lkhmt40j45cv38rv3frnghzkxcx73k7m7afw9j7ujk7nm4dx5mv02r26umxqgar7v3x390w2h3crqqgjsjly7jy4vtwzrmustm5yudpgcydw7x78awca8wqjvkqj8p8e3ykt7lrgd7xf92fsfqjs5vegfsja4ekzpfh5vtccgvs5747xqm6qflmtqpr8s9u")

    var walletBirthDay = Checkpoint.birthday(
        with: 1386000,
        network: ZcashNetworkBuilder.network(for: .testnet)
    )

    var rustBackend: ZcashRustBackendWelding!
    
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var blockRepository: BlockRepository!
    var testTempDirectory: URL!

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        dataDbURL = try! __dataDbURL()
        spendParamsURL = try! __spendParamsURL()
        outputParamsURL = try! __outputParamsURL()
        testTempDirectory = Environment.uniqueTestTempDirectory

        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)

        rustBackend = ZcashRustBackend.makeForTests(
            dbData: dataDbURL,
            fsBlockDbRoot: testTempDirectory,
            networkType: network.networkType
        )

        deleteDBs()
    }
    
    private func deleteDBs() {
        try? FileManager.default.removeItem(at: dataDbURL)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: dataDbURL)
        try? testFileManager.removeItem(at: spendParamsURL)
        try? testFileManager.removeItem(at: outputParamsURL)
        try? testFileManager.removeItem(at: testTempDirectory)
        cancelables = []
        blockRepository = nil
        testTempDirectory = nil
    }
    
    func testSingleDownloadAndScan() async throws {
        logger = OSLogger(logLevel: .debug)

        _ = try await rustBackend.initDataDb(seed: nil)

        let endpoint = LightWalletEndpoint(address: "lightwalletd.testnet.electriccoin.co", port: 9067)
        let service = LightWalletServiceFactory(endpoint: endpoint).make()
        let blockCount = 100
        let range = network.constants.saplingActivationHeight ... network.constants.saplingActivationHeight + blockCount

        let fsBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await fsBlockRepository.create()

        let processorConfig = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: dataDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { [weak self] in self?.walletBirthDay.height ?? .zero },
            network: network
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: fsBlockRepository,
            rustBackend: rustBackend,
            config: processorConfig,
            metrics: SDKMetrics(),
            logger: logger,
            latestBlocksDataProvider: LatestBlocksDataProviderMock()
        )
        
        let repository = BlockSQLDAO(dbProvider: SimpleConnectionProvider.init(path: self.dataDbURL.absoluteString, readonly: true))
        var latestScannedheight = BlockHeight.empty()

        try await compactBlockProcessor.blockDownloaderService.downloadBlockRange(range)
        XCTAssertFalse(Task.isCancelled)
        try await compactBlockProcessor.blockScanner.scanBlocks(at: range, totalProgressRange: range, didScan: { _ in })

        latestScannedheight = repository.lastScannedBlockHeight()
        XCTAssertEqual(latestScannedheight, range.upperBound)
    }

    func observeBenchmark(_ metrics: SDKMetrics) {
        let reports = metrics.popAllBlockReports(flush: true)

        reports.forEach {
            print("observed benchmark: \($0)")
        }
    }

    func testScanValidateDownload() async throws {
        let seed = "testreferencealicetestreferencealice"

        logger = OSLogger(logLevel: .debug)

        let metrics = SDKMetrics()
        metrics.enableMetrics()
        
        guard try await rustBackend.initDataDb(seed: nil) == .success else {
            XCTFail("Seed should not be required for this test")
            return
        }

        let derivationTool = DerivationTool(networkType: .testnet)
        let spendingKey = try await derivationTool.deriveUnifiedSpendingKey(seed: Array(seed.utf8), accountIndex: 0)
        let viewingKey = try await derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

        do {
            try await rustBackend.initAccountsTable(ufvks: [viewingKey])
        } catch {
            XCTFail("failed to init account table. error: \(error)")
            return
        }
        
        try await rustBackend.initBlocksTable(
            height: Int32(walletBirthDay.height),
            hash: walletBirthDay.hash,
            time: walletBirthDay.time,
            saplingTree: walletBirthDay.saplingTree
        )
        
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()

        let fsBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await fsBlockRepository.create()
        
        let processorConfig = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: testTempDirectory,
            dataDb: dataDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            downloadBatchSize: 1000,
            scanningBatchSize: 1000,
            walletBirthdayProvider: { [weak self] in self?.network.constants.saplingActivationHeight ?? .zero },
            network: network
        )
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: fsBlockRepository,
            rustBackend: rustBackend,
            config: processorConfig,
            metrics: metrics,
            logger: logger,
            latestBlocksDataProvider: LatestBlocksDataProviderMock()
        )

        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
            switch event {
            case .progressUpdated: self?.observeBenchmark(metrics)
            default: break
            }
        }

        await compactBlockProcessor.updateEventClosure(identifier: "tests", closure: eventClosure)

        let range = CompactBlockRange(
            uncheckedBounds: (walletBirthDay.height, walletBirthDay.height + 10000)
        )
        
        do {
            let downloadStream = try await compactBlockProcessor.blockDownloader.compactBlocksDownloadStream(
                startHeight: range.lowerBound,
                targetHeight: range.upperBound
            )

            try await compactBlockProcessor.blockDownloader.downloadAndStoreBlocks(
                using: downloadStream,
                at: range,
                maxBlockBufferSize: 10,
                totalProgressRange: range
            )
            XCTAssertFalse(Task.isCancelled)
            
            try await compactBlockProcessor.blockValidator.validate()
            XCTAssertFalse(Task.isCancelled)
            
            try await compactBlockProcessor.blockScanner.scanBlocks(at: range, totalProgressRange: range, didScan: { _ in })
            XCTAssertFalse(Task.isCancelled)
        } catch {
            if let lwdError = error as? ZcashError {
                switch lwdError {
                case .serviceBlockStreamFailed:
                    XCTAssert(true)
                default:
                    XCTFail("LWD Service error found, but should have been a timeLimit reached Error - \(lwdError)")
                }
            } else {
                XCTFail("Error should have been a timeLimit reached Error - \(error)")
            }
        }
        
        metrics.disableMetrics()
    }
}
