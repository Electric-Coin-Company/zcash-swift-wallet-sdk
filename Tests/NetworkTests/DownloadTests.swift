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
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    var network = ZcashNetworkBuilder.network(for: .testnet)

    override func setUpWithError() throws {
        try super.setUpWithError()

        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
    }

    func testSingleDownload() async throws {
        let service = LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try storage.create()

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
            backend: realRustBackend,
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
