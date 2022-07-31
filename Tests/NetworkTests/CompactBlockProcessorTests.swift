//
//  CompactBlockProcessorTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 20/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable force_try implicitly_unwrapped_optional
class CompactBlockProcessorTests: XCTestCase {
    let processorConfig = CompactBlockProcessor.Configuration.standard(
        for: ZcashNetworkBuilder.network(for: .testnet),
        walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
    )
    var processor: CompactBlockProcessor!
    var downloadStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var startedValidatingNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let mockLatestHeight = ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight + 2000
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = SampleLogger(logLevel: .debug)
        
        let service = MockLightWalletService(
            latestBlockHeight: mockLatestHeight,
            service: LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
        )
        let branchID = try ZcashRustBackend.consensusBranchIdFor(height: Int32(mockLatestHeight), networkType: network.networkType)
        service.mockLightDInfo = LightdInfo.with({ info in
            info.blockHeight = UInt64(mockLatestHeight)
            info.branch = "asdf"
            info.buildDate = "today"
            info.buildUser = "testUser"
            info.chainName = "test"
            info.consensusBranchID = branchID.toString()
            info.estimatedHeight = UInt64(mockLatestHeight)
            info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        })
        
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        
        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: ZcashRustBackend.self,
            config: processorConfig
        )
        try ZcashRustBackend.initDataDb(dbData: processorConfig.dataDb, networkType: .testnet)
        downloadStartedExpect = XCTestExpectation(description: "\(self.description) downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: "\(self.description) stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: "\(self.description) updatedNotificationExpectation")
        startedValidatingNotificationExpectation = XCTestExpectation(
            description: "\(self.description) startedValidatingNotificationExpectation"
        )
        startedScanningNotificationExpectation = XCTestExpectation(
            description: "\(self.description) startedScanningNotificationExpectation"
        )
        idleNotificationExpectation = XCTestExpectation(description: "\(self.description) idleNotificationExpectation")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processorFailed(_:)),
            name: Notification.Name.blockProcessorFailed,
            object: processor
        )
    }
    
    override func tearDown() {
        super.tearDown()
        try! FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        downloadStartedExpect.unsubscribeFromNotifications()
        stopNotificationExpectation.unsubscribeFromNotifications()
        updatedNotificationExpectation.unsubscribeFromNotifications()
        startedScanningNotificationExpectation.unsubscribeFromNotifications()
        startedValidatingNotificationExpectation.unsubscribeFromNotifications()
        idleNotificationExpectation.unsubscribeFromNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func processorFailed(_ notification: Notification) {
        XCTAssertNotNil(notification.userInfo)
        if let error = notification.userInfo?["error"] {
            XCTFail("CompactBlockProcessor failed with Error: \(error)")
        } else {
            XCTFail("CompactBlockProcessor failed")
        }
    }
    
    private func startProcessing() {
        XCTAssertNotNil(processor)
        
        // Subscribe to notifications
        downloadStartedExpect.subscribe(to: Notification.Name.blockProcessorStartedDownloading, object: processor)
        stopNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        updatedNotificationExpectation.subscribe(to: Notification.Name.blockProcessorUpdated, object: processor)
        startedValidatingNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedValidating, object: processor)
        startedScanningNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedScanning, object: processor)
        idleNotificationExpectation.subscribe(to: Notification.Name.blockProcessorFinished, object: processor)
        
        XCTAssertNoThrow(try processor.start())
    }
    
    func testStartNotifiesSuscriptors() {
        startProcessing()
   
        wait(
            for: [
                downloadStartedExpect,
                startedValidatingNotificationExpectation,
                startedScanningNotificationExpectation,
                idleNotificationExpectation
            ],
            timeout: 30,
            enforceOrder: true
        )
    }
    
    func testProgressNotifications() {
        let expectedUpdates = expectedBatches(
            currentHeight: processorConfig.walletBirthday,
            targetHeight: mockLatestHeight,
            batchSize: processorConfig.downloadBatchSize
        )
        updatedNotificationExpectation.expectedFulfillmentCount = expectedUpdates
        
        startProcessing()
        wait(for: [updatedNotificationExpectation], timeout: 300)
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight - targetHeight) / batchSize)
    }
}

