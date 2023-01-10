//
//  CompactBlockProcessorOfflineTests.swift
//  
//
//  Created by Michal Fousek on 15.12.2022.
//


import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class CompactBlockProcessorOfflineTests: XCTestCase {
    func testComputeProcessingRangeForSingleLoop() async throws {
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let service = MockLightWalletService(
            latestBlockHeight: 690000,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
        )
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        let processor = CompactBlockProcessor(service: service, storage: storage, backend: ZcashRustBackend.self, config: processorConfig)

        let fullRange = 0...1000

        var range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 0, batchSize: 100)
        XCTAssertEqual(range, 0...99)

        range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 5, batchSize: 100)
        XCTAssertEqual(range, 500...599)

        range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 10, batchSize: 100)
        XCTAssertEqual(range, 1000...1000)
    }
}
