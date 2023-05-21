//
//  BlockStreamingTest.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/25/21.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class BlockStreamingTest: ZcashTestCase {
    let testFileManager = FileManager()
    var rustBackend: ZcashRustBackendWelding!

    override func setUp() async throws {
        try await super.setUp()
        logger = OSLogger(logLevel: .debug)

        rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: .testnet)
        logger = OSLogger(logLevel: .debug)

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
        
        mockContainer.mock(type: LatestBlocksDataProvider.self, isSingleton: true) { _ in LatestBlocksDataProviderMock() }
        mockContainer.mock(type: ZcashRustBackendWelding.self, isSingleton: true) { _ in self.rustBackend }
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        rustBackend = nil
        try? FileManager.default.removeItem(at: __dataDbURL())
        testTempDirectory = nil
    }

    func testStream() async throws {
        let endpoint = LightWalletEndpoint(
            address: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeoutInMillis: 1000,
            streamingCallTimeoutInMillis: 100000
        )
        let service = LightWalletServiceFactory(endpoint: endpoint).make()

        let latestHeight = try await service.latestBlockHeight()
        
        let startHeight = latestHeight - 100_000
        var blocks: [ZcashCompactBlock] = []
        let stream = service.blockStream(startHeight: startHeight, endHeight: latestHeight)
        
        do {
            for try await compactBlock in stream {
                print("received block \(compactBlock.height)")
                blocks.append(compactBlock)
                print("progressHeight: \(compactBlock.height)")
                print("startHeight: \(startHeight)")
                print("targetHeight: \(latestHeight)")
            }
        } catch {
            XCTFail("failed with error: \(error)")
        }
    }
    
    func testStreamCancellation() async throws {
        let endpoint = LightWalletEndpoint(
            address: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeoutInMillis: 10000,
            streamingCallTimeoutInMillis: 10000
        )
        let service = LightWalletServiceFactory(endpoint: endpoint).make()

        let latestBlockHeight = try await service.latestBlockHeight()
        let startHeight = latestBlockHeight - 100_000
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in
            LightWalletServiceFactory(endpoint: endpoint).make()
        }
        try await mockContainer.resolve(CompactBlockRepository.self).create()
        
        let compactBlockProcessor = CompactBlockProcessor(container: mockContainer, config: processorConfig)
        
        let cancelableTask = Task {
            do {
                let blockDownloader = await compactBlockProcessor.blockDownloader
                await blockDownloader.setDownloadLimit(latestBlockHeight)
                try await blockDownloader.setSyncRange(startHeight...latestBlockHeight, batchSize: 100)
                await blockDownloader.startDownload(maxBlockBufferSize: 10)
                try await blockDownloader.waitUntilRequestedBlocksAreDownloaded(in: startHeight...latestBlockHeight)
            } catch {
                XCTAssertTrue(Task.isCancelled)
            }
        }

        cancelableTask.cancel()
        await compactBlockProcessor.stop()
    }
    
    func testStreamTimeout() async throws {
        let endpoint = LightWalletEndpoint(
            address: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeoutInMillis: 1000,
            streamingCallTimeoutInMillis: 1000
        )
        let service = LightWalletServiceFactory(endpoint: endpoint).make()

        let latestBlockHeight = try await service.latestBlockHeight()

        let startHeight = latestBlockHeight - 100_000
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        mockContainer.mock(type: LightWalletService.self, isSingleton: true) { _ in
            LightWalletServiceFactory(endpoint: endpoint).make()
        }
        try await mockContainer.resolve(CompactBlockRepository.self).create()

        let compactBlockProcessor = CompactBlockProcessor(container: mockContainer, config: processorConfig)
        
        let date = Date()
        
        do {
            let blockDownloader = await compactBlockProcessor.blockDownloader
            await blockDownloader.setDownloadLimit(latestBlockHeight)
            try await blockDownloader.setSyncRange(startHeight...latestBlockHeight, batchSize: 100)
            await blockDownloader.startDownload(maxBlockBufferSize: 10)
            try await blockDownloader.waitUntilRequestedBlocksAreDownloaded(in: startHeight...latestBlockHeight)
        } catch {
            if let lwdError = error as? ZcashError {
                switch lwdError {
                case .serviceBlockStreamFailed:
                    XCTAssert(true)
                default:
                    XCTFail("LWD Service error found, but should have been a timeLimit reached \(lwdError)")
                }
            } else {
                XCTFail("Error should have been a timeLimit reached Error")
            }
        }
        
        let now = Date()
        
        let elapsed = now.timeIntervalSince(date)
        print("took \(elapsed) seconds")

        await compactBlockProcessor.stop()
    }
}
