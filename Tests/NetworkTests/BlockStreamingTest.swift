//
//  BlockStreamingTest.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/25/21.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable print_function_usage
class BlockStreamingTest: XCTestCase {
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
        logger = OSLogger(logLevel: .debug)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? FileManager.default.removeItem(at: __dataDbURL())
        try? testFileManager.removeItem(at: testTempDirectory)
    }

    func testStream() async throws {
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 1000,
            streamingCallTimeout: 100000
        )
        
        let latestHeight = try service.latestBlockHeight()
        
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
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 10000,
            streamingCallTimeout: 10000
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            cacheDirectory: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let latestBlockHeight = try service.latestBlockHeight()
        let startHeight = latestBlockHeight - 100_000
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: realRustBackend,
            config: processorConfig
        )
        
        let cancelableTask = Task {
            do {
                let downloadStream = try await compactBlockProcessor.blockDownloader.compactBlocksDownloadStream(
                    startHeight: startHeight,
                    targetHeight: latestBlockHeight
                )

                try await compactBlockProcessor.blockDownloader.downloadAndStoreBlocks(
                    using: downloadStream,
                    at: startHeight...latestBlockHeight,
                    maxBlockBufferSize: 10,
                    totalProgressRange: startHeight...latestBlockHeight
                )
            } catch {
                XCTAssertTrue(Task.isCancelled)
            }
        }
        
        try await Task.sleep(nanoseconds: 3_000_000_000)
        cancelableTask.cancel()
    }
    
    func testStreamTimeout() async throws {
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 1000,
            streamingCallTimeout: 1000
        )

        let realRustBackend = ZcashRustBackend.self

        let storage = FSCompactBlockRepository(
            cacheDirectory: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: realRustBackend
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try storage.create()

        let latestBlockHeight = try service.latestBlockHeight()

        let startHeight = latestBlockHeight - 100_000
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: realRustBackend,
            config: processorConfig
        )
        
        let date = Date()
        
        do {
            let downloadStream = try await compactBlockProcessor.blockDownloader.compactBlocksDownloadStream(
                startHeight: startHeight,
                targetHeight: latestBlockHeight
            )

            try await compactBlockProcessor.blockDownloader.downloadAndStoreBlocks(
                using: downloadStream,
                at: startHeight...latestBlockHeight,
                maxBlockBufferSize: 10,
                totalProgressRange: startHeight...latestBlockHeight
            )
        } catch {
            if let lwdError = error as? LightWalletServiceError {
                switch lwdError {
                case .timeOut:
                    XCTAssert(true)
                default:
                    XCTFail("LWD Service error found, but should have been a timeLimit reached Error")
                }
            } else {
                XCTFail("Error should have been a timeLimit reached Error")
            }
        }
        
        let now = Date()
        
        let elapsed = now.timeIntervalSince(date)
        print("took \(elapsed) seconds")
    }
}
