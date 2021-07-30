//
//  TransactionEnhancementTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/15/20.
//

import XCTest
@testable import ZcashLightClientKit
class TransactionEnhancementTests: XCTestCase {
    var initializer: Initializer!
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
    var txFoundNotificationExpectation: XCTestExpectation!
    var waitExpectation: XCTestExpectation!
    let mockLatestHeight = BlockHeight(663250)
    let targetLatestHeight = BlockHeight(663251)
    let walletBirthday = BlockHeight(663150)
    let network = DarksideWalletDNetwork()
    let branchID = "2bb40e60"
    let chainName = "main"
    override func setUpWithError() throws {
        logger = SampleLogger(logLevel: .debug)
        
        downloadStartedExpect = XCTestExpectation(description: self.description + " downloadStartedExpect")
        stopNotificationExpectation = XCTestExpectation(description: self.description + " stopNotificationExpectation")
        updatedNotificationExpectation = XCTestExpectation(description: self.description + " updatedNotificationExpectation")
        startedValidatingNotificationExpectation = XCTestExpectation(description: self.description + " startedValidatingNotificationExpectation")
        startedScanningNotificationExpectation = XCTestExpectation(description: self.description + " startedScanningNotificationExpectation")
        idleNotificationExpectation = XCTestExpectation(description: self.description + " idleNotificationExpectation")
        afterReorgIdleNotification = XCTestExpectation(description: self.description + " afterReorgIdleNotification")
        reorgNotificationExpectation = XCTestExpectation(description: self.description + " reorgNotificationExpectation")
        txFoundNotificationExpectation = XCTestExpectation(description: self.description + "txFoundNotificationExpectation")
        
        waitExpectation = XCTestExpectation(description: self.description + "waitExpectation")
        
        let birthday = WalletBirthday.birthday(with: walletBirthday, network: network)
        
        let config = CompactBlockProcessor.Configuration.standard(for: self.network, walletBirthday: birthday.height)
        let rustBackend = ZcashRustBackend.self
        processorConfig = config
        
        
        
        try? FileManager.default.removeItem(at: processorConfig.cacheDb)
        try? FileManager.default.removeItem(at: processorConfig.dataDb)
        
        _ = rustBackend.initAccountsTable(dbData: processorConfig.dataDb, seed: TestSeed().seed(), accounts: 1,networkType: network.networkType)
        _ = try rustBackend.initDataDb(dbData: processorConfig.dataDb, networkType: network.networkType)
        _ = try rustBackend.initBlocksTable(dbData: processorConfig.dataDb, height: Int32(birthday.height), hash: birthday.hash, time: birthday.time, saplingTree: birthday.tree, networkType: network.networkType)
        
        let service = DarksideWalletService()
        darksideWalletService = service
        let storage = CompactBlockStorage.init(connectionProvider: SimpleConnectionProvider(path: processorConfig.cacheDb.absoluteString))
        try! storage.createTable()
        
        downloader = CompactBlockDownloader(service: service, storage: storage)
        processor = CompactBlockProcessor(service: service,
                                          storage: storage,
                                          backend: rustBackend,
                                          config: processorConfig)
        
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(processorFailed(_:)), name: Notification.Name.blockProcessorFailed, object: processor)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: processorConfig.cacheDb)
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
    
    fileprivate func startProcessing() throws {
        XCTAssertNotNil(processor)
        
        // Subscribe to notifications
        downloadStartedExpect.subscribe(to: Notification.Name.blockProcessorStartedDownloading, object: processor)
        stopNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStopped, object: processor)
        updatedNotificationExpectation.subscribe(to: Notification.Name.blockProcessorUpdated, object: processor)
        startedValidatingNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedValidating, object: processor)
        startedScanningNotificationExpectation.subscribe(to: Notification.Name.blockProcessorStartedScanning, object: processor)
        

        try processor.start()
    }
    
    func testBasicEnhacement() throws {
        
        let targetLatestHeight = BlockHeight(663250)
        let walletBirthday = WalletBirthday.birthday(with: 663151, network: network).height
        
        try basicEnhancementTest(latestHeight: targetLatestHeight, walletBirthday: walletBirthday)
    }
    
    func basicEnhancementTest(latestHeight: BlockHeight, walletBirthday: BlockHeight) throws {
     
        do {
            try darksideWalletService.reset(saplingActivation: 663150, branchID: branchID, chainName: chainName)
            try darksideWalletService.useDataset(DarksideDataset.beforeReOrg.rawValue)
            try darksideWalletService.applyStaged(nextLatestHeight: 663200)
        } catch  {
            XCTFail("Error: \(error)")
            return
        }
      
        sleep(3)
        /**
         connect to dLWD
         request latest height -> receive firstLatestHeight
         */
        do {
             print("first latest height:  \(try darksideWalletService.latestBlockHeight())")
        } catch {
            XCTFail("Error: \(error)")
            return
        }

        
        /**
         download and sync blocks from walletBirthday to firstLatestHeight
         */
        do {
            
            try startProcessing()
             
        } catch {
            XCTFail("Error: \(error)")
        }
       
        wait(for: [downloadStartedExpect,
                   startedValidatingNotificationExpectation,
                   startedScanningNotificationExpectation,
                   txFoundNotificationExpectation,
                   idleNotificationExpectation], timeout: 30)
        idleNotificationExpectation.unsubscribeFromNotifications()

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

