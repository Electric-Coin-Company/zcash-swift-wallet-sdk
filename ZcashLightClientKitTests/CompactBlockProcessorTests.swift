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
    var expect: XCTestExpectation!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        XCTAssertTrue(MockDbInit.emptyFile(at: processorConfig.cacheDbPath))
        XCTAssertTrue(MockDbInit.emptyFile(at: processorConfig.dataDbPath))
        
        
        
        let service = LightWalletGRPCService(channel: ChannelProvider().channel())
        let storage = ZcashConsoleFakeStorage()
        let downloader = CompactBlockDownloader(service: service, storage: storage)
        expect = XCTestExpectation(description: self.description)
        processor = CompactBlockProcessor(downloader: downloader,
                                            backend: ZcashRustBackend.self,
                                            config: processorConfig,
                                            service: service)
    }
    
    override func tearDown() {
        
        do {
            try MockDbInit.destroy(at: processorConfig.cacheDbPath)
            try MockDbInit.destroy(at: processorConfig.dataDbPath)
        } catch {
            XCTFail(error.localizedDescription)
        }
        
        expect.unsuscribeFromNotifications()
        
        
    }
    
    
    func testStartNotifiesSuscriptors() {
        
        
        XCTAssertNotNil(processor)
        expect.suscribe(to: Notification.Name.blockProcessorStarted, object: processor)
        
        XCTAssertNoThrow(try processor.start())
        
        wait(for: [expect], timeout: 5)
    }
    
}
