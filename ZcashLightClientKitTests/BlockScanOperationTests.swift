//
//  BlockScanOperationTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/17/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
import SQLite
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_try force_unwrapping print_function_usage
class BlockScanOperationTests: XCTestCase {
    let rustWelding = ZcashRustBackend.self

    var operationQueue = OperationQueue()
    var cacheDbURL: URL!
    var dataDbURL: URL!

    var uvk = UVFakeKey(
        extfvk: "zxviewtestsapling1qw88ayg8qqqqpqyhg7jnh9mlldejfqwu46pm40ruwstd8znq3v3l4hjf33qcu2a5e36katshcfhcxhzgyfugj2lkhmt40j45cv38rv3frnghzkxcx73k7m7afw9j7ujk7nm4dx5mv02r26umxqgar7v3x390w2h3crqqgjsjly7jy4vtwzrmustm5yudpgcydw7x78awca8wqjvkqj8p8e3ykt7lrgd7xf92fsfqjs5vegfsja4ekzpfh5vtccgvs5747xqm6qflmtqpr8s9u", // swiftlint:disable:this line_length
        extpub: "02075a7f5f7507d64022dad5954849f216b0f1b09b2d588be663d8e7faeb5aaf61"
    )

    var walletBirthDay = WalletBirthday.birthday(
        with: 1386000,
        network: ZcashNetworkBuilder.network(for: .testnet)
    )
    
    var network = ZcashNetworkBuilder.network(for: .testnet)
    var blockRepository: BlockRepository!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        self.cacheDbURL = try! __cacheDbURL()
        self.dataDbURL = try! __dataDbURL()
        
        deleteDBs()
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    private func deleteDBs() {
        try? FileManager.default.removeItem(at: cacheDbURL)
        try? FileManager.default.removeItem(at: dataDbURL)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        operationQueue.cancelAllOperations()
        
        try? FileManager.default.removeItem(at: cacheDbURL)
        try? FileManager.default.removeItem(at: dataDbURL)
    }
    
    func testSingleDownloadAndScanOperation() {
        logger = SampleLogger(logLevel: .debug)

        XCTAssertNoThrow(try rustWelding.initDataDb(dbData: dataDbURL, networkType: network.networkType))

        let downloadStartedExpect = XCTestExpectation(description: "\(self.description) download started")
        let downloadExpect = XCTestExpectation(description: "\(self.description) download")
        let scanStartedExpect = XCTestExpectation(description: "\(self.description) scan started")
        let scanExpect = XCTestExpectation(description: "\(self.description) scan")
        let latestScannedBlockExpect = XCTestExpectation(description: "\(self.description) latestScannedHeight")
        let service = LightWalletGRPCService(
            endpoint: LightWalletEndpoint(
                address: "lightwalletd.testnet.electriccoin.co",
                port: 9067
            )
        )
        let blockCount = 100
        let range = network.constants.saplingActivationHeight ... network.constants.saplingActivationHeight + blockCount
        let downloadOperation = CompactBlockDownloadOperation(
            downloader: CompactBlockDownloader.sqlDownloader(
                service: service,
                at: cacheDbURL
            )!,
            range: range
        )
        let scanOperation = CompactBlockScanningOperation(
            rustWelding: rustWelding,
            cacheDb: cacheDbURL,
            dataDb: dataDbURL,
            networkType: network.networkType
        )
        
        downloadOperation.startedHandler = {
            downloadStartedExpect.fulfill()
        }
        
        downloadOperation.completionHandler = { finished, cancelled in
            downloadExpect.fulfill()
            XCTAssertTrue(finished)
            XCTAssertFalse(cancelled)
        }
        
        downloadOperation.errorHandler = { error in
            XCTFail("Download Operation failed with Error: \(error)")
        }
        
        scanOperation.startedHandler = {
            scanStartedExpect.fulfill()
        }
        
        scanOperation.completionHandler = { finished, cancelled in
            scanExpect.fulfill()
            XCTAssertFalse(cancelled)
            XCTAssertTrue(finished)
        }
        
        scanOperation.errorHandler = { error in
            XCTFail("Scan Operation failed with Error: \(error)")
        }
        
        scanOperation.addDependency(downloadOperation)
        var latestScannedheight = BlockHeight.empty()
        let latestScannedBlockOperation = BlockOperation {
            let repository = BlockSQLDAO(dbProvider: SimpleConnectionProvider.init(path: self.dataDbURL.absoluteString, readonly: true))
            latestScannedheight = repository.lastScannedBlockHeight()
        }
        
        latestScannedBlockOperation.completionBlock = {
            latestScannedBlockExpect.fulfill()
            XCTAssertEqual(latestScannedheight, range.upperBound)
        }
        
        latestScannedBlockOperation.addDependency(scanOperation)
        
        operationQueue.addOperations(
            [downloadOperation, scanOperation, latestScannedBlockOperation],
            waitUntilFinished: false
        )

        wait(
            for: [downloadStartedExpect, downloadExpect, scanStartedExpect, scanExpect, latestScannedBlockExpect],
            timeout: 10,
            enforceOrder: true
        )
    }
    @objc func observeBenchmark(_ notification: Notification) {
        guard let report = SDKMetrics.blockReportFromNotification(notification) else {
            return
        }
        
        print("observed benchmark: \(report)")
    }
    func testScanValidateDownload() throws {
        logger = SampleLogger(logLevel: .debug)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(observeBenchmark(_:)),
            name: SDKMetrics.notificationName,
            object: nil
        )
         
        try self.rustWelding.initDataDb(dbData: dataDbURL, networkType: network.networkType)

        guard try self.rustWelding.initAccountsTable(dbData: self.dataDbURL, uvks: [uvk], networkType: network.networkType) else {
            XCTFail("failed to init account table")
            return
        }
        
        try self.rustWelding.initBlocksTable(
            dbData: dataDbURL,
            height: Int32(walletBirthDay.height),
            hash: walletBirthDay.hash,
            time: walletBirthDay.time,
            saplingTree: walletBirthDay.tree,
            networkType: network.networkType
        )
        
        let service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.eccTestnet)
        let storage = CompactBlockStorage(url: cacheDbURL, readonly: false)
        try storage.createTable()
        
        let downloadExpectation = XCTestExpectation(description: "download expectation")
        let validateExpectation = XCTestExpectation(description: "validate expectation")
        let scanExpectation = XCTestExpectation(description: "scan expectation")
        
        let downloadOperation = CompactBlockStreamDownloadOperation(
            service: service,
            storage: storage,
            startHeight: walletBirthDay.height,
            targetHeight: walletBirthDay.height + 10000,
            progressDelegate: self
        )
        
        downloadOperation.completionHandler = { finished, cancelled in
            XCTAssert(finished)
            XCTAssertFalse(cancelled)
            downloadExpectation.fulfill()
        }
        
        downloadOperation.errorHandler = { error in
            if let lwdError = error as? LightWalletServiceError {
                switch lwdError {
                case .timeOut:
                    XCTAssert(true)
                default:
                    XCTFail("LWD Service error found, but should have been a timeLimit reached Error - \(lwdError)")
                }
            } else {
                XCTFail("Error should have been a timeLimit reached Error - \(error)")
            }
        }
        
        let validationOperation = CompactBlockValidationOperation(
            rustWelding: rustWelding,
            cacheDb: cacheDbURL,
            dataDb: dataDbURL,
            networkType: network.networkType
        )

        validationOperation.errorHandler = { error in
            self.operationQueue.cancelAllOperations()
            XCTFail("failed with error \(error)")
        }

        validationOperation.completionHandler = { finished, cancelled in
            XCTAssert(finished)
            XCTAssertFalse(cancelled)
            validateExpectation.fulfill()
        }
        
        let transactionRepository = TransactionRepositoryBuilder.build(dataDbURL: dataDbURL)
        let scanningOperation = CompactBlockBatchScanningOperation(
            rustWelding: rustWelding,
            cacheDb: cacheDbURL,
            dataDb: dataDbURL,
            transactionRepository: transactionRepository,
            range: CompactBlockRange(
                uncheckedBounds: (walletBirthDay.height, walletBirthDay.height + 10000)
            ),
            batchSize: 1000,
            networkType: network.networkType,
            progressDelegate: self
        )
        
        scanningOperation.completionHandler = { finished, cancelled in
            XCTAssert(finished)
            XCTAssertFalse(cancelled)
            scanExpectation.fulfill()
        }

        operationQueue.addOperations([downloadOperation, validationOperation, scanningOperation], waitUntilFinished: false)
        
        wait(for: [downloadExpectation, validateExpectation, scanExpectation], timeout: 300, enforceOrder: true)
    }
}

extension BlockScanOperationTests: CompactBlockProgressDelegate {
    func progressUpdated(_ progress: CompactBlockProgress) {
    }
}

struct UVFakeKey: UnifiedViewingKey {
    var extfvk: ExtendedFullViewingKey
    var extpub: ExtendedPublicKey
}
