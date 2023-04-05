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

    override func setUpWithError() throws {
        try super.setUpWithError()

        try self.testFileManager.createDirectory(at: Environment.testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: Environment.testTempDirectory)
    }

    func testSingleDownload() async throws {
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        let rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: Environment.testTempDirectory, networkType: network.networkType)

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: Environment.testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: Environment.testTempDirectory,
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
            logger: logger
        )
        
        do {
            try await compactBlockProcessor.blockDownloaderService.downloadBlockRange(range)
        } catch {
            XCTFail("Download failed with error: \(error)")
        }

        let latestHeight = await storage.latestHeight()
        XCTAssertEqual(latestHeight, range.upperBound)
    }
}
