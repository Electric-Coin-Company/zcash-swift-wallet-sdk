//
//  BlockScanTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/17/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import SQLite
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_try print_function_usage
class BlockScanTests: XCTestCase {
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
    }
    
    func testSingleDownloadAndScan() async throws {
        logger = OSLogger(logLevel: .debug)

        XCTAssertNoThrow(try rustWelding.initDataDb(dbData: dataDbURL, seed: nil, networkType: network.networkType))

        let endpoint = LightWalletEndpoint(address: "lightwalletd.testnet.electriccoin.co", port: 9067)
        let service = LightWalletServiceFactory(endpoint: endpoint, connectionStateChange: { _, _ in }).make()
        let blockCount = 100
        let range = network.constants.saplingActivationHeight ... network.constants.saplingActivationHeight + blockCount

        let fsDbRootURL = self.testTempDirectory

        let rustBackend = ZcashRustBackend.self
        let fsBlockRepository = FSCompactBlockRepository(
            cacheDirectory: fsDbRootURL,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: fsDbRootURL,
                rustBackend: rustBackend
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try fsBlockRepository.create()

        let processorConfig = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: fsDbRootURL,
            dataDb: dataDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            walletBirthday: walletBirthDay.height,
            network: network
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: fsBlockRepository,
            backend: rustBackend,
            config: processorConfig
        )
        
        let repository = BlockSQLDAO(dbProvider: SimpleConnectionProvider.init(path: self.dataDbURL.absoluteString, readonly: true))
        var latestScannedheight = BlockHeight.empty()

        try await compactBlockProcessor.blockDownloaderService.downloadBlockRange(range)
        XCTAssertFalse(Task.isCancelled)
        try await compactBlockProcessor.blockScanner.scanBlocks(at: range, totalProgressRange: range, didScan: { _ in })

        latestScannedheight = repository.lastScannedBlockHeight()
        XCTAssertEqual(latestScannedheight, range.upperBound)
    }
    
    @objc func observeBenchmark(_ notification: Notification) {
        let reports = SDKMetrics.shared.popAllBlockReports(flush: true)
        
        reports.forEach {
            print("observed benchmark: \($0)")
        }
    }
    
    func testScanValidateDownload() async throws {
        let seed = "testreferencealicetestreferencealice"

        logger = OSLogger(logLevel: .debug)

        SDKMetrics.shared.enableMetrics()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(observeBenchmark(_:)),
            name: .blockProcessorUpdated,
            object: nil
        )
        
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
        
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet, connectionStateChange: { _, _ in }).make()

        let fsDbRootURL = self.testTempDirectory

        let fsBlockRepository = FSCompactBlockRepository(
            cacheDirectory: fsDbRootURL,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: fsDbRootURL,
                rustBackend: rustWelding
            ),
            blockDescriptor: ZcashCompactBlockDescriptor.live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try fsBlockRepository.create()
        
        var processorConfig = CompactBlockProcessor.Configuration(
            fsBlockCacheRoot: fsDbRootURL,
            dataDb: dataDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            walletBirthday: network.constants.saplingActivationHeight,
            network: network
        )
        processorConfig.scanningBatchSize = 1000
        
        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: fsBlockRepository,
            backend: rustWelding,
            config: processorConfig
        )
        
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
        
        SDKMetrics.shared.disableMetrics()
    }
}
