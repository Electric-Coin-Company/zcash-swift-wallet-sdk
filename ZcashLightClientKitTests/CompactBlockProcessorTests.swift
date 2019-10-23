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
    var finishedDownloadingNotificationExpectation: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var startedScanningNotificationExpectation: XCTestExpectation!
    var finishedScanningNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let service = MockLightWalletService(latestBlockHeight: 281_000)
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        
        processor = CompactBlockProcessor(downloader: downloader,
                                            backend: ZcashRustBackend.self,
                                            config: processorConfig,
                                            service: service)
        
        downloadStartedExpect = XCTestExpectation(description: self.description + " downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        finishedDownloadingNotificationExpectation = XCTestExpectation(description: self.description + " finishedDownloadingNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: self.description + " updatedNotificationExpectation")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        startedScanningNotificationExpectation = XCTestExpectation(description: self.description + " startedScanningNotificationExpectation")
        finishedScanningNotificationExpectation = XCTestExpectation(description: self.description + " finishedScanningNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: self.description + " idleNotificationExpectation")
        
    }
    
    override func tearDown() {
        
        try? FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        downloadStartedExpect.unsuscribeFromNotifications()
        stopNotificationExpectation.unsuscribeFromNotifications()
    }
    
    func testStartNotifiesSuscriptors() {
        
        XCTAssertNotNil(processor)
        
        
        
        downloadStartedExpect.suscribe(to: Notification.Name.blockProcessorStartedDownloading, object: processor)
        stopNotificationExpectation.suscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        XCTAssertNoThrow(try processor.start())
        processor.stop()
        wait(for: [downloadStartedExpect,stopNotificationExpectation], timeout: 5,enforceOrder: true)
        
        
    }
    
}
