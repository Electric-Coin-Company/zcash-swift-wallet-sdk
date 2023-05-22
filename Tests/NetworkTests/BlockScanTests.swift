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

class BlockScanTests: ZcashTestCase {
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

    override func setUp() async throws {
        try await super.setUp()
        logger = OSLogger(logLevel: .debug)
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
        
        Dependencies.setup(
            in: mockContainer,
            urls: Initializer.URLs(
                fsBlockDbRoot: testTempDirectory,
                dataDbURL: dataDbURL,
                spendParamsURL: spendParamsURL,
                outputParamsURL: outputParamsURL
            ),
            alias: .default,
            networkType: .testnet,
            endpoint: LightWalletEndpointBuilder.default,
            loggingPolicy: .default(.debug)
        )

        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in LatestBlocksDataProviderMock() }
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in self.rustBackend }
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
    
//    func testSingleDownloadAndScan() async throws {
//        _ = try await rustBackend.initDataDb(seed: nil)
//
//        let endpoint = LightWalletEndpoint(address: "lightwalletd.testnet.electriccoin.co", port: 9067)
//        let blockCount = 100
//        let range = network.constants.saplingActivationHeight ... network.constants.saplingActivationHeight + blockCount
//
//        let processorConfig = CompactBlockProcessor.Configuration(
//            alias: .default,
//            fsBlockCacheRoot: testTempDirectory,
//            dataDb: dataDbURL,
//            spendParamsURL: spendParamsURL,
//            outputParamsURL: outputParamsURL,
//            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
//            walletBirthdayProvider: { [weak self] in self?.walletBirthDay.height ?? .zero },
//            network: network
//        )
//
//        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in
//            LightWalletServiceFactory(endpoint: endpoint).make()
//        }
//        try await mockContainer.resolve(CompactBlockRepository.self).create()
//
//        let compactBlockProcessor = CompactBlockProcessor(container: mockContainer, config: processorConfig)
//
//        let repository = BlockSQLDAO(dbProvider: SimpleConnectionProvider.init(path: self.dataDbURL.absoluteString, readonly: true))
//        var latestScannedheight = BlockHeight.empty()
//
//        try await compactBlockProcessor.blockDownloaderService.downloadBlockRange(range)
//        XCTAssertFalse(Task.isCancelled)
//        try await compactBlockProcessor.blockScanner.scanBlocks(at: range, totalProgressRange: range, didScan: { _ in })
//
//        latestScannedheight = repository.lastScannedBlockHeight()
//        XCTAssertEqual(latestScannedheight, range.upperBound)
//
//        await compactBlockProcessor.stop()
//    }

    func observeBenchmark(_ metrics: SDKMetrics) {
        let reports = metrics.popAllBlockReports(flush: true)

        reports.forEach {
            print("observed benchmark: \($0)")
        }
    }

//    func testScanValidateDownload() async throws {
//        let seed = "testreferencealicetestreferencealice"
//
//        let metrics = SDKMetrics()
//        metrics.enableMetrics()
//
//        guard try await rustBackend.initDataDb(seed: nil) == .success else {
//            XCTFail("Seed should not be required for this test")
//            return
//        }
//
//        let derivationTool = DerivationTool(networkType: .testnet)
//        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(seed: Array(seed.utf8), accountIndex: 0)
//        let viewingKey = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)
//
//        do {
//            try await rustBackend.initAccountsTable(ufvks: [viewingKey])
//        } catch {
//            XCTFail("failed to init account table. error: \(error)")
//            return
//        }
//
//        try await rustBackend.initBlocksTable(
//            height: Int32(walletBirthDay.height),
//            hash: walletBirthDay.hash,
//            time: walletBirthDay.time,
//            saplingTree: walletBirthDay.saplingTree
//        )
//
//        let processorConfig = CompactBlockProcessor.Configuration(
//            alias: .default,
//            fsBlockCacheRoot: testTempDirectory,
//            dataDb: dataDbURL,
//            spendParamsURL: spendParamsURL,
//            outputParamsURL: outputParamsURL,
//            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
//            batchSize: 1000,
//            walletBirthdayProvider: { [weak self] in self?.network.constants.saplingActivationHeight ?? .zero },
//            network: network
//        )
//
//        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in
//            LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
//        }
//        try await mockContainer.resolve(CompactBlockRepository.self).create()
//
//        let compactBlockProcessor = CompactBlockProcessor(container: mockContainer, config: processorConfig)
//
//        let eventClosure: CompactBlockProcessor.EventClosure = { [weak self] event in
//            switch event {
//            case .progressUpdated: self?.observeBenchmark(metrics)
//            default: break
//            }
//        }
//
//        await compactBlockProcessor.updateEventClosure(identifier: "tests", closure: eventClosure)
//
//        let range = CompactBlockRange(
//            uncheckedBounds: (walletBirthDay.height, walletBirthDay.height + 10000)
//        )
//
//        do {
//            let blockDownloader = await compactBlockProcessor.blockDownloader
//            await blockDownloader.setDownloadLimit(range.upperBound)
//            try await blockDownloader.setSyncRange(range, batchSize: 100)
//            await blockDownloader.startDownload(maxBlockBufferSize: 10)
//            try await blockDownloader.waitUntilRequestedBlocksAreDownloaded(in: range)
//
//            XCTAssertFalse(Task.isCancelled)
//
//            try await compactBlockProcessor.blockValidator.validate()
//            XCTAssertFalse(Task.isCancelled)
//
//            try await compactBlockProcessor.blockScanner.scanBlocks(at: range, totalProgressRange: range, didScan: { _ in })
//            XCTAssertFalse(Task.isCancelled)
//        } catch {
//            if let lwdError = error as? ZcashError {
//                switch lwdError {
//                case .serviceBlockStreamFailed:
//                    XCTAssert(true)
//                default:
//                    XCTFail("LWD Service error found, but should have been a timeLimit reached Error - \(lwdError)")
//                }
//            } else {
//                XCTFail("Error should have been a timeLimit reached Error - \(error)")
//            }
//        }
//
//        await compactBlockProcessor.stop()
//        metrics.disableMetrics()
//    }
}
