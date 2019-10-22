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
    var startExpect: XCTestExpectation!
    var stopExpect: XCTestExpectation!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let service = LightWalletGRPCService(channel: ChannelProvider().channel())
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        startExpect = XCTestExpectation(description: self.description + " start")
        stopExpect = XCTestExpectation(description: self.description + " stop")
        processor = CompactBlockProcessor(downloader: downloader,
                                            backend: ZcashRustBackend.self,
                                            config: processorConfig,
                                            service: service)
    }
    
    override func tearDown() {
        
        try? FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        startExpect.unsuscribeFromNotifications()
        
    }
    
    func testStartNotifiesSuscriptors() {
        
        XCTAssertNotNil(processor)
        startExpect.suscribe(to: Notification.Name.blockProcessorStarted, object: processor)
        startExpect.suscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        XCTAssertNoThrow(try processor.start())
        processor.stop()
        wait(for: [startExpect,stopExpect], timeout: 5,enforceOrder: true)
        
        
    }
    
}
