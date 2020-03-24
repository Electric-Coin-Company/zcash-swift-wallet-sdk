//
//  ReOrgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import XCTest
@testable import ZcashLightClientKit
/**
 basic reorg test.  Scan, get a reorg and then reach latest height.
    
 * connect to dLWD
 * request latest height -> receive 663250
 * download and sync blocks from 663150 to 663250
 * trigger reorg by calling API (no need to pass params)**
 * request latest height -> receive 663251!
 * download that block
 * observe that the prev hash of that block does not match the hash that we have for 663250
 * rewind 10 blocks and request blocks 663241 to 663251
 */
class ReOrgTests: XCTestCase {
    
    var processorConfig: CompactBlockProcessor.Configuration!
    var processor: CompactBlockProcessor!
    var darksideWalletService: DarksideWalletService!
    var downloader: CompactBlockDownloader!
    var downloadStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var startedValidatingNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    var reorgNotificationExpectation: XCTestExpectation!
    var afterReorgIdleNotification: XCTestExpectation!
    let mockLatestHeight = BlockHeight(663250)
    let targetLatestHeight = BlockHeight(663251)
    let walletBirthday = BlockHeight(663150)
    
    override func setUpWithError() throws {
        var config = CompactBlockProcessor.Configuration.standard
        
        config.walletBirthday = walletBirthday
        processorConfig = config
        
        let service = DarksideWalletService()
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        downloader = CompactBlockDownloader(service: service, storage: storage)
        processor = CompactBlockProcessor(downloader: downloader,
                                          backend: ZcashRustBackend.self,
                                            config: processorConfig)
        
        downloadStartedExpect = XCTestExpectation(description: self.description + " downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: self.description + " updatedNotificationExpectation")
        startedValidatingNotificationExpectation = XCTestExpectation(description: self.description + " startedValidatingNotificationExpectation")
        startedScanningNotificationExpectation = XCTestExpectation(description: self.description + " startedScanningNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: self.description + " idleNotificationExpectation")
        afterReorgIdleNotification = XCTestExpectation(description: self.description + " afterReorgIdleNotification")
        reorgNotificationExpectation = XCTestExpectation(description: self.description + " reorgNotificationExpectation")
        
        NotificationCenter.default.addObserver(self, selector: #selector(processorHandledReorg(_:)), name: Notification.Name.blockProcessorHandledReOrg, object: processor)
        NotificationCenter.default.addObserver(self, selector: #selector(processorFailed(_:)), name: Notification.Name.blockProcessorFailed, object: processor)
    }

    override func tearDownWithError() throws {
        try! FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        downloadStartedExpect.unsubscribeFromNotifications()
        stopNotificationExpectation.unsubscribeFromNotifications()
        updatedNotificationExpectation.unsubscribeFromNotifications()
        startedScanningNotificationExpectation.unsubscribeFromNotifications()
        startedValidatingNotificationExpectation.unsubscribeFromNotifications()
        idleNotificationExpectation.unsubscribeFromNotifications()
        reorgNotificationExpectation.unsubscribeFromNotifications()
        afterReorgIdleNotification.unsubscribeFromNotifications()
        NotificationCenter.default.removeObserver(self)
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
    func testBasicReOrg() throws {
        
        try basicReOrgTest(firstLatestHeight: mockLatestHeight, walletBirthday: walletBirthday, targetHeight: targetLatestHeight)
    }
    
    func basicReOrgTest(firstLatestHeight: BlockHeight, walletBirthday: BlockHeight, targetHeight: BlockHeight) throws {
        
        var latestHeight = BlockHeight(0)
        
        /**
        connect to dLWD
        request latest height -> receive firstLatestHeight
        */
        XCTAssertNoThrow(try { latestHeight = try darksideWalletService.latestBlockHeight() }())
        XCTAssertEqual(latestHeight, firstLatestHeight)
        
        /**
         download and sync blocks from walletBirthday to firstLatestHeight
         */
        startProcessing()
        wait(for: [idleNotificationExpectation], timeout: 30)
        
        idleNotificationExpectation.unsubscribeFromNotifications()
        
        /**
            verify that mock height has been reached
         */
        var latestDownloadedHeight = BlockHeight(0)
        XCTAssertNoThrow(try {latestDownloadedHeight = try downloader.lastDownloadedBlockHeight()}())
        XCTAssertEqual(latestDownloadedHeight, firstLatestHeight)
        
        /**
         trigger reorg!
         */
        darksideWalletService.triggerReOrg()
        
        /**
         request latest height -> receive targetHeight!
         */
        
        XCTAssertNoThrow(try {latestDownloadedHeight = try downloader.lastDownloadedBlockHeight()}())
        afterReorgIdleNotification.subscribe(to: .blockProcessorIdle, object: processor)
        
        /**
         request latest height -> receive targetHeight!
         download that block
         observe that the prev hash of that block does not match the hash that we have for firstLatestHeight
         rewind 10 blocks and request blocks targetHeight-10 to targetHeight
         */
        try processor.start(retry: true)
        
        // now reorg should happen and reorg notifications and idle notification should be triggered
        
        wait(for: [reorgNotificationExpectation, afterReorgIdleNotification], timeout: 10)
        
        // now everything should be fine. latest block should be targetHeight
        
         XCTAssertNoThrow(try {latestDownloadedHeight = try downloader.lastDownloadedBlockHeight()}())
               XCTAssertEqual(latestDownloadedHeight, targetHeight)
    }

    @objc func processorHandledReorg(_ notification: Notification) {

                XCTAssertNotNil(notification.userInfo)
                if let reorg = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
                    let rewind = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight {
                    XCTAssertEqual(reorg, mockLatestHeight)
                    XCTAssertTrue( rewind <= mockLatestHeight - processorConfig.rewindDistance)
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
}