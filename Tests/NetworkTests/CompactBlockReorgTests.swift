//
//  CompactBlockReorgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/13/19.
//
//  Copyright © 2019 Electric Coin Company. All rights reserved.

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_try
class CompactBlockReorgTests: XCTestCase {
    let processorConfig = CompactBlockProcessor.Configuration.standard(
        for: ZcashNetworkBuilder.network(for: .testnet),
        walletBirthday: ZcashNetworkBuilder.network(for: .testnet).constants.saplingActivationHeight
    )
    var processor: CompactBlockProcessor!
    var syncStartedExpect: XCTestExpectation!
    var updatedNotificationExpectation: XCTestExpectation!
    var stopNotificationExpectation: XCTestExpectation!
    var idleNotificationExpectation: XCTestExpectation!
    var reorgNotificationExpectation: XCTestExpectation!
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
        service.mockLightDInfo = LightdInfo.with { info in
            info.blockHeight = UInt64(mockLatestHeight)
            info.branch = "asdf"
            info.buildDate = "today"
            info.buildUser = "testUser"
            info.chainName = "test"
            info.consensusBranchID = branchID.toString()
            info.estimatedHeight = UInt64(mockLatestHeight)
            info.saplingActivationHeight = UInt64(network.constants.saplingActivationHeight)
        }
        
        guard case .success = try ZcashRustBackend.initDataDb(dbData: processorConfig.dataDb, seed: nil, networkType: .testnet) else {
            XCTFail("initDataDb failed. Expected Success but got .seedRequired")
            return 
        }
        
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        
        let mockBackend = MockRustBackend.self
        mockBackend.mockValidateCombinedChainFailAfterAttempts = 3
        mockBackend.mockValidateCombinedChainKeepFailing = false
        mockBackend.mockValidateCombinedChainFailureHeight = self.network.constants.saplingActivationHeight + 320
        
        processor = CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: mockBackend,
            config: processorConfig
        )
        
        syncStartedExpect = XCTestExpectation(description: "\(self.description) syncStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: "\(self.description) stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: "\(self.description) updatedNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: "\(self.description) idleNotificationExpectation")
        reorgNotificationExpectation = XCTestExpectation(description: "\(self.description) reorgNotificationExpectation")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processorHandledReorg(_:)),
            name: Notification.Name.blockProcessorHandledReOrg,
            object: processor
        )

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
        syncStartedExpect.unsubscribeFromNotifications()
        stopNotificationExpectation.unsubscribeFromNotifications()
        updatedNotificationExpectation.unsubscribeFromNotifications()
        idleNotificationExpectation.unsubscribeFromNotifications()
        reorgNotificationExpectation.unsubscribeFromNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func processorHandledReorg(_ notification: Notification) {
        XCTAssertNotNil(notification.userInfo)
        if  let reorg = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewind = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight {
            XCTAssertTrue( reorg == 0 || reorg > self.network.constants.saplingActivationHeight)
            XCTAssertTrue( rewind == 0 || rewind > self.network.constants.saplingActivationHeight)
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
    
    private func startProcessing() async {
        XCTAssertNotNil(processor)
        
        // Subscribe to notifications
        syncStartedExpect.subscribe(to: Notification.Name.blockProcessorStartedSyncing, object: processor)
        stopNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        updatedNotificationExpectation.subscribe(to: Notification.Name.blockProcessorUpdated, object: processor)
        idleNotificationExpectation.subscribe(to: Notification.Name.blockProcessorFinished, object: processor)
        reorgNotificationExpectation.subscribe(to: Notification.Name.blockProcessorHandledReOrg, object: processor)

        await processor.start()
    }
    
    func testNotifiesReorg() async {
        await startProcessing()

        wait(
            for: [
                syncStartedExpect,
                reorgNotificationExpectation,
                idleNotificationExpectation
            ],
            timeout: 300,
            enforceOrder: true
        )
    }
    
    private func expectedBatches(currentHeight: BlockHeight, targetHeight: BlockHeight, batchSize: Int) -> Int {
        (abs(currentHeight - targetHeight) / batchSize)
    }
}
