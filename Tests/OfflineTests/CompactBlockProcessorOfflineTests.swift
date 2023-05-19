//
//  CompactBlockProcessorOfflineTests.swift
//  
//
//  Created by Michal Fousek on 15.12.2022.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class CompactBlockProcessorOfflineTests: ZcashTestCase {
    let testFileManager = FileManager()

    override func setUpWithError() throws {
        try super.setUpWithError()

        Dependencies.setup(
            in: mockContainer,
            urls: Initializer.URLs(
                fsBlockDbRoot: testTempDirectory,
                dataDbURL: try! __dataDbURL(),
                generalStorageURL: testGeneralStorageDirectory,
                spendParamsURL: try! __spendParamsURL(),
                outputParamsURL: try! __outputParamsURL()
            ),
            alias: .default,
            networkType: .testnet,
            endpoint: LightWalletEndpointBuilder.default,
            loggingPolicy: .default(.debug)
        )
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    // TODO: [#1095] review this test https://github.com/zcash/ZcashLightClientKit/issues/1095
//    func testComputeProcessingRangeForSingleLoop() async throws {
//        let network = ZcashNetworkBuilder.network(for: .testnet)
//        let rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: .testnet)
//
//        let processorConfig = CompactBlockProcessor.Configuration.standard(
//            for: network,
//            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
//        )
//
//        let service = MockLightWalletService(
//            latestBlockHeight: 690000,
//            service: LightWalletServiceFactory(endpoint: LightWalletEndpointBuilder.eccTestnet).make()
//        )
//        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in service }
//
//        let storage = FSCompactBlockRepository(
//            fsBlockDbRoot: testTempDirectory,
//            metadataStore: FSMetadataStore.live(
//                fsBlockDbRoot: testTempDirectory,
//                rustBackend: rustBackend,
//                logger: logger
//            ),
//            blockDescriptor: .live,
//            contentProvider: DirectoryListingProviders.defaultSorted,
//            logger: logger
//        )
//        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in storage }
//        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in LatestBlocksDataProviderMock() }
//
//        let processor = CompactBlockProcessor(
//            container: mockContainer,
//            config: processorConfig
//        )
//
//        let fullRange = 0...1000
//
//        var range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 0, batchSize: 100)
//        XCTAssertEqual(range, 0...99)
//
//        range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 5, batchSize: 100)
//        XCTAssertEqual(range, 500...599)
//
//        range = await processor.computeSingleLoopDownloadRange(fullRange: fullRange, loopCounter: 10, batchSize: 100)
//        XCTAssertEqual(range, 1000...1000)
//    }
}
