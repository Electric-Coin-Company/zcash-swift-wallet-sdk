//
//  DownloadTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import SQLite
@testable import TestUtils
@testable import ZcashLightClientKit

class DownloadTests: XCTestCase {
    let testFileManager = FileManager()
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var testTempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        testTempDirectory = Environment.uniqueTestTempDirectory
        try? FileManager.default.removeItem(at: testTempDirectory)
        await InternalSyncProgress(alias: .default, storage: UserDefaults.standard, logger: logger).rewind(to: 0)

        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
        testTempDirectory = nil
    }

    func testSingleDownload() async throws {
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        let rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: network.networkType)

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

        try await storage.create()

        let blockCount = 100
        let activationHeight = network.constants.saplingActivationHeight
        let range = activationHeight ... activationHeight + blockCount
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: network,
            walletBirthday: network.constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            rustBackend: rustBackend,
            config: processorConfig,
            metrics: SDKMetrics(),
            logger: logger,
            latestBlocksDataProvider: LatestBlocksDataProviderMock()
        )
        
        do {
            try await compactBlockProcessor.blockDownloaderService.downloadBlockRange(range)
        } catch {
            XCTFail("Download failed with error: \(error)")
        }

        let latestHeight = await storage.latestHeight()
        XCTAssertEqual(latestHeight, range.upperBound)

        await compactBlockProcessor.stop()
    }
}
