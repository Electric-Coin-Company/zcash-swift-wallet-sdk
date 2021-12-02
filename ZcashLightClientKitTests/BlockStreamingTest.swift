//
//  BlockStreamingTest.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/25/21.
//

import XCTest
@testable import ZcashLightClientKit

// swiftlint:disable print_function_usage
class BlockStreamingTest: XCTestCase {
    var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = SampleLogger(logLevel: .debug)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? FileManager.default.removeItem(at: __dataDbURL())
    }

    func testStreamOperation() throws {
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
    
    func testStreamOperationCancellation() throws {
        let expectation = XCTestExpectation(description: "blockstream expectation")
        
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 10000,
            streamingCallTimeout: 10000
        )
        let storage = try TestDbBuilder.inMemoryCompactBlockStorage()
        
        let startHeight = try service.latestBlockHeight() - 100_000
        let operation = CompactBlockStreamDownloadOperation(
            service: service,
            storage: storage,
            startHeight: startHeight,
            progressDelegate: self
        )
        
        operation.completionHandler = { _, cancelled in
            XCTAssert(cancelled)
            expectation.fulfill()
        }
        
        operation.errorHandler = { error in
            XCTFail("failed with error: \(error)")
            expectation.fulfill()
        }
        
        queue.addOperation(operation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            self.queue.cancelAllOperations()
        })
        wait(for: [expectation], timeout: 1000)
    }
    
    func testStreamOperationTimeout() throws {
        let expectation = XCTestExpectation(description: "blockstream expectation")
        let errorExpectation = XCTestExpectation(description: "blockstream error expectation")
        let service = LightWalletGRPCService(
            host: LightWalletEndpointBuilder.eccTestnet.host,
            port: 9067,
            secure: true,
            singleCallTimeout: 1000,
            streamingCallTimeout: 3000
        )
        let storage = try TestDbBuilder.inMemoryCompactBlockStorage()
        
        let startHeight = try service.latestBlockHeight() - 100_000
        let operation = CompactBlockStreamDownloadOperation(
            service: service,
            storage: storage,
            startHeight: startHeight,
            progressDelegate: self
        )
        
        operation.completionHandler = { finished, _ in
            XCTAssert(finished)
            
            expectation.fulfill()
        }
        
        operation.errorHandler = { error in
            if let lwdError = error as? LightWalletServiceError {
                switch lwdError {
                case .timeOut:
                    XCTAssert(true)
                default:
                    XCTFail("LWD Service erro found, but should have been a timeLimit reached Error")
                }
            } else {
                XCTFail("Error should have been a timeLimit reached Error")
            }
            errorExpectation.fulfill()
        }
        
        queue.addOperation(operation)
        let date = Date()
        wait(for: [errorExpectation], timeout: 4)
        let now = Date()
        
        let elapsed = now.distance(to: date)
        print("took \(elapsed) seconds")
    }
    
    func testBatchOperation() throws {
        let expectation = XCTestExpectation(description: "blockbatch expectation")
        
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
        let operation = CompactBlockBatchDownloadOperation(
            service: service,
            storage: storage,
            startHeight: startHeight,
            targetHeight: targetHeight,
            progressDelegate: self
        )
        
        operation.completionHandler = { _, cancelled in
            if cancelled {
                XCTFail("operation cancelled")
            }
            expectation.fulfill()
        }
        
        operation.errorHandler = { error in
            XCTFail("failed with error: \(error)")
            expectation.fulfill()
        }
        
        queue.addOperation(operation)
        
        wait(for: [expectation], timeout: 120)
    }

    func testBatchOperationCancellation() throws {
        let expectation = XCTestExpectation(description: "blockbatch expectation")
        
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
        let operation = CompactBlockBatchDownloadOperation(
            service: service,
            storage: storage,
            startHeight: startHeight,
            targetHeight: targetHeight,
            progressDelegate: self
        )
        
        operation.completionHandler = { _, cancelled in
            XCTAssert(cancelled)
            expectation.fulfill()
        }
        
        operation.errorHandler = { error in
            XCTFail("failed with error: \(error)")
            expectation.fulfill()
        }
        
        queue.addOperation(operation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            self.queue.cancelAllOperations()
        })
        wait(for: [expectation], timeout: 1000)
    }
}

extension BlockStreamingTest: CompactBlockProgressDelegate {
    func progressUpdated(_ progress: CompactBlockProgress) {
        print("progressHeight: \(String(describing: progress.progressHeight))")
        print("startHeight: \(progress.progress)")
        print("targetHeight: \(String(describing: progress.targetHeight))")
    }
}
