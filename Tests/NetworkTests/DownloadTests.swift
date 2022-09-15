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

// swiftlint:disable force_try
class DownloadTests: XCTestCase {
    var network = ZcashNetworkBuilder.network(for: .testnet)

    override func tearDown() {
        super.tearDown()
    }

    func testSingleDownload() async throws {
        let service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
        let storage = try! TestDbBuilder.inMemoryCompactBlockStorage()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
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
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        
        do {
            try await compactBlockProcessor.compactBlockDownload(downloader: downloader, range: range)
        } catch {
            XCTFail("Download failed with error: \(error)")
        }
        
        XCTAssertEqual(try! storage.latestHeight(), range.upperBound)
    }
}
