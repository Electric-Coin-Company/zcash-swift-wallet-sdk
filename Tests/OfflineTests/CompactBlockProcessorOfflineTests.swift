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
    let testFileManager = FileManager()
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    override func setUpWithError() throws {
        try super.setUpWithError()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try FileManager.default.removeItem(at: self.testTempDirectory)
    }

    func testComputeProcessingRangeForSingleLoop() async throws {
        let network = ZcashNetworkBuilder.network(for: .testnet)
        let realRustBackend = ZcashRustBackend.self

        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: network,
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let service = MockLightWalletService(
            latestBlockHeight: 690000,
            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
        )

        let storage = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )
        
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
