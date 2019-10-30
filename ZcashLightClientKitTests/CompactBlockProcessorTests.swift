//
//  CompactBlockProcessorTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 20/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import ZcashLightClientKit
class CompactBlockProcessorTests: XCTestCase {
    
    let processorConfig = CompactBlockProcessor.Configuration.standard
    var processor: CompactBlockProcessor!
    var downloadStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var startedValidatingNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    let mockLatestHeight = 282_000
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let service = MockLightWalletService(latestBlockHeight: mockLatestHeight)
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        
        processor = CompactBlockProcessor(downloader: downloader,
                                            backend: ZcashRustBackend.self,
                                            config: processorConfig,
                                            service: service)
        
        downloadStartedExpect = XCTestExpectation(description: self.description + " downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: self.description + " updatedNotificationExpectation")
        startedValidatingNotificationExpectation = XCTestExpectation(description: self.description + " startedValidatingNotificationExpectation")
        startedScanningNotificationExpectation = XCTestExpectation(description: self.description + " startedScanningNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: self.description + " idleNotificationExpectation")
        NotificationCenter.default.addObserver(self, selector: #selector(processorFailed(_:)), name: Notification.Name.blockProcessorFailed, object: processor)
    }
    
    override func tearDown() {
        
        try! FileManager.default.removeItem(at: processorConfig.cacheDb)
        try! FileManager.default.removeItem(at: processorConfig.dataDb)
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
    
    fileprivate func startProcessing() {
        XCTAssertNotNil(processor)
        
        // Subscribe to notifications
        downloadStartedExpect.subscribe(to: Notification.Name.blockProcessorStartedDownloading, object: processor)
        stopNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        updatedNotificationExpectation.subscribe(to: Notification.Name.blockProcessorUpdated, object: processor)
        startedValidatingNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedValidating, object: processor)
        startedScanningNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedScanning, object: processor)
        idleNotificationExpectation.subscribe(to: Notification.Name.blockProcessorIdle, object: processor)
        
        XCTAssertNoThrow(try processor.start())
    }
    
    func testStartNotifiesSuscriptors() {
        
        startProcessing()
   
        wait(for: [
                   downloadStartedExpect,
                   startedValidatingNotificationExpectation,
                   startedScanningNotificationExpectation,
                   idleNotificationExpectation,
                   ], timeout: 130,enforceOrder: true)
    }
    
    func testProgressNotifications() {
        
        let expectedUpdates = expectedBatches(currentHeight: processorConfig.walletBirthday, targetHeight: mockLatestHeight, batchSize: processorConfig.downloadBatchSize)
        updatedNotificationExpectation.expectedFulfillmentCount = expectedUpdates
        
        startProcessing()
        wait(for: [updatedNotificationExpectation], timeout: 130)
        
        
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight-targetHeight)/batchSize)
    }
    
    func testNextBatchBlockRange() {
        
        // test first range
        var latestDownloadedHeight = processorConfig.walletBirthday // this can be either this or Wallet Birthday.
        var latestBlockchainHeight = BlockHeight(281_000)
        
        var expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight, upper:latestDownloadedHeight + processorConfig.downloadBatchSize - 1))
        
        XCTAssertEqual(expectedBatchRange, processor.nextBatchBlockRange(latestHeight: latestBlockchainHeight, latestDownloadedHeight: latestDownloadedHeight))
        
        // Test mid-range
        latestDownloadedHeight = BlockHeight(280_100)
        latestBlockchainHeight = BlockHeight(281_000)
        
        expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight + 1, upper:latestDownloadedHeight + processorConfig.downloadBatchSize))
        
        XCTAssertEqual(expectedBatchRange, processor.nextBatchBlockRange(latestHeight: latestBlockchainHeight, latestDownloadedHeight: latestDownloadedHeight))
        
        latestDownloadedHeight = BlockHeight(280_950)
        latestBlockchainHeight = BlockHeight(281_000)
        
        // Test last batch range
        
        latestDownloadedHeight = BlockHeight(280_950)
        latestBlockchainHeight = BlockHeight(281_000)
        
        expectedBatchRange = CompactBlockRange(uncheckedBounds: (lower: latestDownloadedHeight + 1, upper: latestBlockchainHeight))
        
        XCTAssertEqual(expectedBatchRange, processor.nextBatchBlockRange(latestHeight: latestBlockchainHeight, latestDownloadedHeight: latestDownloadedHeight))
    }
}
