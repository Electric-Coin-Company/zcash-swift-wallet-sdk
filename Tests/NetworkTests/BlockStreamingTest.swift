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
    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = SampleLogger(logLevel: .debug)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? FileManager.default.removeItem(at: __dataDbURL())
    }

    func testStream() throws {
        let expectation = XCTestExpectation(description: "blockstream expectation")
        
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
        service.blockStream(startHeight: startHeight, endHeight: latestHeight) { result in
            expectation.fulfill()
            switch result {
            case .success(let status):
                XCTAssertEqual(GRPCResult.success, status)
            case .failure(let error):
                XCTFail("failed with error: \(error)")
            }
        } handler: { compactBlock in
            print("received block \(compactBlock.height)")
            blocks.append(compactBlock)
        } progress: { progressReport in
            print("progressHeight: \(progressReport.progressHeight)")
            print("startHeight: \(progressReport.startHeight)")
            print("targetHeight: \(progressReport.targetHeight)")
        }
        wait(for: [expectation], timeout: 1000)
    }
    
    func testStreamCancellation() async throws {
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 10000,
            streamingCallTimeout: 10000
        )

        let storage = try TestDbBuilder.inMemoryCompactBlockStorage()
        let startHeight = try service.latestBlockHeight() - 100_000
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        
        let cancelableTask = Task {
            do {
                try await compactBlockProcessor.compactBlockStreamDownload(
                    blockBufferSize: 10,
                    startHeight: startHeight
                )
                XCTAssertTrue(Task.isCancelled)
            } catch {
                XCTFail("failed with error: \(error)")
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
            streamingCallTimeout: 3000
        )

        let storage = try TestDbBuilder.inMemoryCompactBlockStorage()
        let startHeight = try service.latestBlockHeight() - 100_000
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        
        let date = Date()
        
        do {
            try await compactBlockProcessor.compactBlockStreamDownload(
                blockBufferSize: 10,
                startHeight: startHeight
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
    
    func testBatch() async throws {
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 300000,
            streamingCallTimeout: 10000
        )
        let storage = try TestDbBuilder.diskCompactBlockStorage(at: __dataDbURL() )
        let targetHeight = try service.latestBlockHeight()
        let startHeight = targetHeight - 10_000
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        
        let range = CompactBlockRange(uncheckedBounds: (startHeight, targetHeight))
        do {
            try await compactBlockProcessor.compactBlockBatchDownload(range: range)
            XCTAssertFalse(Task.isCancelled)
        } catch {
            XCTFail("failed with error: \(error)")
        }
    }

    func testBatchCancellation() async throws {
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 300000,
            streamingCallTimeout: 10000
        )
        let storage = try TestDbBuilder.diskCompactBlockStorage(at: __dataDbURL() )
        let targetHeight = try service.latestBlockHeight()
        let startHeight = targetHeight - 100_000
        
        let processorConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet),
            walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
        )

        let compactBlockProcessor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        
        let range = CompactBlockRange(uncheckedBounds: (startHeight, targetHeight))
        let cancelableTask = Task {
            do {
                try await compactBlockProcessor.compactBlockBatchDownload(range: range)
                XCTAssertTrue(Task.isCancelled)
            } catch {
                XCTFail("failed with error: \(error)")
            }
        }
        
        try await Task.sleep(nanoseconds: 3_000_000_000)
        cancelableTask.cancel()
    }
}
