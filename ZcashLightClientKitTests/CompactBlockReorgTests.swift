//
//  CompactBlockReorgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/13/19.
//
//  Copyright © 2019 Electric Coin Company. All rights reserved.


import XCTest
@testable import ZcashLightClientKit
class CompactBlockReorgTests: XCTestCase {
    
    let processorConfig = CompactBlockProcessor.Configuration.standard
    var processor: CompactBlockProcessor!
    var downloadStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var startedValidatingNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    var reorgNotificationExpectation: XCTestExpectation!
    let mockLatestHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 2000
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let service = MockLightWalletService(latestBlockHeight: mockLatestHeight)
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        
        let mockBackend = MockRustBackend.self
        mockBackend.mockValidateCombinedChainFailAfterAttempts = 3
        mockBackend.mockValidateCombinedChainKeepFailing = false
        mockBackend.mockValidateCombinedChainFailureHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT + 320
        
        processor = CompactBlockProcessor(downloader: downloader,
                                            backend: mockBackend,
                                            config: processorConfig)
        
        downloadStartedExpect = XCTestExpectation(description: self.description + " downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: self.description + " updatedNotificationExpectation")
        startedValidatingNotificationExpectation = XCTestExpectation(description: self.description + " startedValidatingNotificationExpectation")
        startedScanningNotificationExpectation = XCTestExpectation(description: self.description + " startedScanningNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: self.description + " idleNotificationExpectation")
        reorgNotificationExpectation = XCTestExpectation(description: self.description + " reorgNotificationExpectation")
        
        NotificationCenter.default.addObserver(self, selector: #selector(processorHandledReorg(_:)), name: Notification.Name.blockProcessorHandledReOrg, object: processor)
        NotificationCenter.default.addObserver(self, selector: #selector(processorFailed(_:)), name: Notification.Name.blockProcessorFailed, object: processor)
    }
    
    override func tearDown() {
        try! FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        downloadStartedExpect.unsubscribeFromNotifications()
        stopNotificationExpectation.unsubscribeFromNotifications()
        updatedNotificationExpectation.unsubscribeFromNotifications()
        startedScanningNotificationExpectation.unsubscribeFromNotifications()
        startedValidatingNotificationExpectation.unsubscribeFromNotifications()
        idleNotificationExpectation.unsubscribeFromNotifications()
        reorgNotificationExpectation.unsubscribeFromNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func processorHandledReorg(_ notification: Notification) {

            XCTAssertNotNil(notification.userInfo)
            if let reorg = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
                let rewind = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight {
                XCTAssertTrue( reorg == 0 || reorg > ZcashSDK.SAPLING_ACTIVATION_HEIGHT)
                XCTAssertTrue( rewind == 0 || rewind > ZcashSDK.SAPLING_ACTIVATION_HEIGHT)
                XCTAssertTrue( rewind <= reorg )
                reorgNotificationExpectation.fulfill()
            } else {
                XCTFail("CompactBlockProcessor reorg notification is malformed")
            }
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
        reorgNotificationExpectation.subscribe(to: Notification.Name.blockProcessorHandledReOrg, object: processor)
        
        XCTAssertNoThrow(try processor.start())
    }
    
    func testNotifiesReorg() {
        
        startProcessing()
   
        wait(for: [
                   downloadStartedExpect,
                   startedValidatingNotificationExpectation,
                   startedScanningNotificationExpectation,
                   reorgNotificationExpectation,
                   idleNotificationExpectation,
                   ], timeout: 300,enforceOrder: true)
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight-targetHeight)/batchSize)
    }
    
}
