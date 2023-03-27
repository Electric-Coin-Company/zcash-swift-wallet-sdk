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

    let rustWelding = ZcashRustBackend.self

    var dataDbURL: URL!
    var spendParamsURL: URL!
    var outputParamsURL: URL!
    // swiftlint:disable:next line_length
    var saplingExtendedKey = SaplingExtendedFullViewingKey(validatedEncoding: "zxviewtestsapling1qw88ayg8qqqqpqyhg7jnh9mlldejfqwu46pm40ruwstd8znq3v3l4hjf33qcu2a5e36katshcfhcxhzgyfugj2lkhmt40j45cv38rv3frnghzkxcx73k7m7afw9j7ujk7nm4dx5mv02r26umxqgar7v3x390w2h3crqqgjsjly7jy4vtwzrmustm5yudpgcydw7x78awca8wqjvkqj8p8e3ykt7lrgd7xf92fsfqjs5vegfsja4ekzpfh5vtccgvs5747xqm6qflmtqpr8s9u")

    var walletBirthDay = Checkpoint.birthday(
        with: 1386000,
        network: ZcashNetworkBuilder.network(for: .testnet)
    )
    
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var blockRepository: BlockRepository!

    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        self.dataDbURL = try! __dataDbURL()
        self.spendParamsURL = try! __spendParamsURL()
        self.outputParamsURL = try! __outputParamsURL()

        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)

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
    }
    
    func testSingleDownloadAndScan() async throws {
        logger = OSLogger(logLevel: .debug)

        XCTAssertNoThrow(try rustWelding.initDataDb(dbData: dataDbURL, seed: nil, networkType: network.networkType))

        let endpoint = LightWalletEndpoint(address: "lightwalletd.testnet.electriccoin.co", port: 9067)
        let service = LightWalletServiceFactory(endpoint: endpoint).make()
        let blockCount = 100
        let range = network.constants.saplingActivationHeight ... network.constants.saplingActivationHeight + blockCount

        let fsDbRootURL = self.testTempDirectory

        let rustBackend = ZcashRustBackend.self
        let fsBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: fsDbRootURL,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: fsDbRootURL,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try fsBlockRepository.create()

        let processorConfig = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: fsDbRootURL,
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
            backend: rustBackend,
            config: processorConfig,
            metrics: SDKMetrics(),
            logger: logger
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
        
        guard try self.rustWelding.initDataDb(dbData: dataDbURL, seed: nil, networkType: network.networkType) == .success else {
            XCTFail("Seed should not be required for this test")
            return
        }

        let derivationTool = DerivationTool(networkType: .testnet)
        let ufvk = try derivationTool
            .deriveUnifiedSpendingKey(seed: Array(seed.utf8), accountIndex: 0)
            .map { try derivationTool.deriveUnifiedFullViewingKey(from: $0) }

        do {
            try self.rustWelding.initAccountsTable(
                dbData: self.dataDbURL,
                ufvks: [ufvk],
                networkType: network.networkType
            )
        } catch {
            XCTFail("failed to init account table. error: \(self.rustWelding.getLastError() ?? "no error found")")
            return
        }
        
        try self.rustWelding.initBlocksTable(
            dbData: dataDbURL,
            height: Int32(walletBirthDay.height),
            hash: walletBirthDay.hash,
            time: walletBirthDay.time,
            saplingTree: walletBirthDay.saplingTree,
            networkType: network.networkType
        )
        
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()

        let fsDbRootURL = self.testTempDirectory

        let fsBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: fsDbRootURL,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: fsDbRootURL,
                rustBackend: rustWelding,
                logger: logger
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try fsBlockRepository.create()
        
        var processorConfig = CompactBlockProcessor.Configuration(
            alias: .default,
            fsBlockCacheRoot: fsDbRootURL,
            dataDb: dataDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { [weak self] in self?.network.constants.saplingActivationHeight ?? .zero },
            network: network
        )
        processorConfig.scanningBatchSize = 1000
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: fsBlockRepository,
            backend: rustWelding,
            config: processorConfig,
            metrics: metrics,
            logger: logger
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
            if let lwdError = error as? LightWalletServiceError {
                switch lwdError {
                case .timeOut:
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
