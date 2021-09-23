//
//  BlockBatchValidationTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 6/17/21.
//

import XCTest
@testable import ZcashLightClientKit

// swiftlint:disable force_try type_body_length
class BlockBatchValidationTests: XCTestCase {
    var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Test Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testBranchIdFailure() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db33f"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = Int32(0xd34d)

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let expectation = XCTestExpectation(description: "failure expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { error in
            expectation.fulfill()
            switch error {
            case CompactBlockProcessorError.wrongConsensusBranchId:
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.wrongConsensusBranchId but found \(error)")
            }
        }
        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, expectation], timeout: 1, enforceOrder: true)
        XCTAssertNotNil(operation.error)
        XCTAssertTrue(operation.isCancelled)
    }
    
    func testBranchNetworkMismatchFailure() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )
        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "test"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let expectation = XCTestExpectation(description: "failure expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { error in
            expectation.fulfill()
            switch error {
            case CompactBlockProcessorError.networkMismatch(expected: .mainnet, found: .testnet):
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.networkMismatch but found \(error)")
            }
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, expectation], timeout: 1, enforceOrder: true)
        XCTAssertNotNil(operation.error)
        XCTAssertTrue(operation.isCancelled)
    }
    
    func testBranchNetworkTypeWrongFailure() throws {
        let network = ZcashNetworkBuilder.network(for: .testnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )
        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "another"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let expectation = XCTestExpectation(description: "failure expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { error in
            expectation.fulfill()
            switch error {
            case CompactBlockProcessorError.generalError:
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.generalError but found \(error)")
            }
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, expectation], timeout: 1, enforceOrder: true)
        XCTAssertNotNil(operation.error)
        XCTAssertTrue(operation.isCancelled)
    }
    
    func testSaplingActivationHeightMismatch() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let service = MockLightWalletService(
            latestBlockHeight: 1210000,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: 1220000)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = 130000
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(3434343)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let expectation = XCTestExpectation(description: "failure expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { error in
            expectation.fulfill()
            switch error {
            case CompactBlockProcessorError.saplingActivationMismatch(
                expected: network.constants.saplingActivationHeight,
                found: BlockHeight(info.saplingActivationHeight)
            ):
                break
            default:
                XCTFail("Expected CompactBlockProcessorError.saplingActivationMismatch but found \(error)")
            }
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, expectation], timeout: 1, enforceOrder: true)
        XCTAssertNotNil(operation.error)
        XCTAssertTrue(operation.isCancelled)
    }
    
    func testResultIsWait() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        
        let expectedLatestHeight = BlockHeight(1210000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let expectedStoreLatestHeight = BlockHeight(1220000)
        let expectedResult = FigureNextBatchOperation.NextState.wait(
            latestHeight: expectedLatestHeight,
            latestDownloadHeight: expectedLatestHeight
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoreLatestHeight)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: 1210000,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let completedExpectation = XCTestExpectation(description: "completed expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { error in
            XCTFail("this shouldn't happen: \(error)")
        }

        operation.completionHandler = { finished, cancelled in
            completedExpectation.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, completedExpectation], timeout: 1, enforceOrder: true)
        XCTAssertNil(operation.error)
        XCTAssertFalse(operation.isCancelled)

        guard let result = operation.result else {
            XCTFail("result should not be nil")
            return
        }
        
        XCTAssertTrue(
            {
                switch result {
                case .wait(latestHeight: expectedLatestHeight, latestDownloadHeight: expectedLatestHeight):
                    return true
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(result)"
        )
    }
    
    func testResultProcessNew() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let expectedLatestHeight = BlockHeight(1230000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let expectedStoreLatestHeight = BlockHeight(1220000)
        let walletBirthday = BlockHeight(1210000)
        let expectedResult = FigureNextBatchOperation.NextState.processNewBlocks(
            range: CompactBlockProcessor.nextBatchBlockRange(
                latestHeight: expectedLatestHeight,
                latestDownloadedHeight: expectedStoreLatestHeight,
                walletBirthday: walletBirthday
            )
        )
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoreLatestHeight)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: walletBirthday,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let completedExpectation = XCTestExpectation(description: "completed expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { _ in
            XCTFail("this shouldn't happen")
        }

        operation.completionHandler = { finished, cancelled in
            completedExpectation.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, completedExpectation], timeout: 1, enforceOrder: true)
        XCTAssertNil(operation.error)
        XCTAssertFalse(operation.isCancelled)

        guard let result = operation.result else {
            XCTFail("result should not be nil")
            return
        }
        
        XCTAssertTrue(
            {
                switch result {
                case .processNewBlocks(range: CompactBlockRange(uncheckedBounds: (expectedStoreLatestHeight + 1, expectedLatestHeight))):
                    return true
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(result)"
        )
    }
    
    func testResultProcessorFinished() throws {
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let expectedLatestHeight = BlockHeight(1230000)
        let service = MockLightWalletService(
            latestBlockHeight: expectedLatestHeight,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        )
        let expectedStoreLatestHeight = BlockHeight(1230000)
        let walletBirthday = BlockHeight(1210000)
        let expectedResult = FigureNextBatchOperation.NextState.finishProcessing(height: expectedStoreLatestHeight)
        let repository = ZcashConsoleFakeStorage(latestBlockHeight: expectedStoreLatestHeight)
        let downloader = CompactBlockDownloader(service: service, storage: repository)
        let config = CompactBlockProcessor.Configuration(
            cacheDb: try!  __cacheDbURL(),
            dataDb: try! __dataDbURL(),
            downloadBatchSize: 100,
            retries: 5,
            maxBackoffInterval: 10,
            rewindDistance: 100,
            walletBirthday: walletBirthday,
            saplingActivation: network.constants.saplingActivationHeight,
            network: network
        )

        var info = LightdInfo()
        info.blockHeight = UInt64(expectedLatestHeight)
        info.branch = "d34db33f"
        info.chainName = "main"
        info.buildUser = "test user"
        info.consensusBranchID = "d34db4d"
        info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)

        service.mockLightDInfo = info
        
        let mockRust = MockRustBackend.self
        mockRust.consensusBranchID = 0xd34db4d

        let operation = FigureNextBatchOperation(downloader: downloader, service: service, config: config, rustBackend: mockRust)
        let completedExpectation = XCTestExpectation(description: "completed expectation")
        let startedExpectation = XCTestExpectation(description: "start Expectation")

        operation.startedHandler = {
            startedExpectation.fulfill()
        }

        operation.errorHandler = { _ in
            XCTFail("this shouldn't happen")
        }

        operation.completionHandler = { finished, cancelled in
            completedExpectation.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }

        queue.addOperations([operation], waitUntilFinished: false)
        
        wait(for: [startedExpectation, completedExpectation], timeout: 1, enforceOrder: true)
        XCTAssertNil(operation.error)
        XCTAssertFalse(operation.isCancelled)

        guard let result = operation.result else {
            XCTFail("result should not be nil")
            return
        }
        
        XCTAssertTrue(
            {
                switch result {
                case .finishProcessing(height: expectedLatestHeight):
                    return true
                default:
                    return false
                }
            }(),
            "Expected \(expectedResult) got: \(result)"
        )
    }
}
