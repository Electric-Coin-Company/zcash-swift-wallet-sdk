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

class DownloadTests: ZcashTestCase {
    let testFileManager = FileManager()
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var testTempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        testTempDirectory = Environment.uniqueTestTempDirectory
        try? FileManager.default.removeItem(at: testTempDirectory)
        await InternalSyncProgress(alias: .default, storage: UserDefaults.standard, logger: logger).rewind(to: 0)

        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)
        
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
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
        testTempDirectory = nil
    }

    func testSingleDownload() async throws {
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in
            ZcashRustBackend.makeForTests(fsBlockDbRoot: self.testTempDirectory, networkType: self.network.networkType)
        }
        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in
            LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        }
        let storage = mockContainer.resolve(CompactBlockRepository.self)
        try await storage.create()

        let blockCount = 100
        let activationHeight = network.constants.saplingActivationHeight
        let range = activationHeight ... activationHeight + blockCount
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: network,
            walletBirthday: network.constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(container: mockContainer, config: processorConfig)
        
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
