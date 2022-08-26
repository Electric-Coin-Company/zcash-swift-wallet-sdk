//
//  BlockDownloaderTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_cast force_try
class BlockDownloaderTests: XCTestCase {
    let branchID = "2bb40e60"
    let chainName = "main"

    var darksideWalletService: DarksideWalletService!
    var downloader: CompactBlockDownloading!
    var service: LightWalletService!
    var storage: CompactBlockRepository!
    var cacheDB = try! __cacheDbURL()
    var network = DarksideWalletDNetwork()

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        storage = try! TestDbBuilder.diskCompactBlockStorage(at: cacheDB)
        downloader = CompactBlockDownloader(service: service, storage: storage)
        darksideWalletService = DarksideWalletService(service: service as! LightWalletGRPCService)
        
        try FakeChainBuilder.buildChain(darksideWallet: darksideWalletService, branchID: branchID, chainName: chainName)
        try darksideWalletService.applyStaged(nextLatestHeight: 663250)
    }
    
    override func tearDown() {
        service = nil
        storage = nil
        downloader = nil
        try? FileManager.default.removeItem(at: cacheDB)
    }
    
    func testSmallDownloadAsync() {
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 3
        let lowerRange: BlockHeight = self.network.constants.saplingActivationHeight
        let upperRange: BlockHeight = self.network.constants.saplingActivationHeight + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange, upperRange))
        downloader.downloadBlockRange(range) { error in
            expect.fulfill()
            XCTAssertNil(error)
            
            Task {
                do {
                    // check what was 'stored'
                    let latestHeight = try await self.storage.latestHeightAsync()
                    expect.fulfill()

                    XCTAssertEqual(latestHeight, upperRange)

                    self.downloader.lastDownloadedBlockHeight { resultHeight in
                        expect.fulfill()
                        XCTAssertTrue(self.validate(result: resultHeight, against: upperRange))
                    }
                } catch {
                    XCTFail("testSmallDownloadAsync() shouldn't fail")
                }
            }
        }
        
        wait(for: [expect], timeout: 2)
    }
    
    func testSmallDownload() {
        let lowerRange: BlockHeight = self.network.constants.saplingActivationHeight
        let upperRange: BlockHeight = self.network.constants.saplingActivationHeight + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange, upperRange))
        var latest: BlockHeight = 0
        
        do {
            latest = try downloader.lastDownloadedBlockHeight()
        } catch {
            XCTFail(error.localizedDescription)
        }
        
        XCTAssertEqual(latest, BlockHeight.empty())
        XCTAssertNoThrow(try downloader.downloadBlockRange(range))
        
        var currentLatest: BlockHeight = 0
        do {
            currentLatest = try downloader.lastDownloadedBlockHeight()
        } catch {
            XCTFail("latest block failed")
            return
        }

        XCTAssertEqual(currentLatest, upperRange )
    }
    
    func testFailure() {
        let awfulDownloader = CompactBlockDownloader(
            service: AwfulLightWalletService(
                latestBlockHeight: self.network.constants.saplingActivationHeight + 1000,
                service: darksideWalletService
            ),
            storage: ZcashConsoleFakeStorage()
        )
        
        let expect = XCTestExpectation(description: self.description)
        expect.expectedFulfillmentCount = 1
        let lowerRange: BlockHeight = self.network.constants.saplingActivationHeight
        let upperRange: BlockHeight = self.network.constants.saplingActivationHeight + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange, upperRange))
        
        awfulDownloader.downloadBlockRange(range) { error in
            expect.fulfill()
            XCTAssertNotNil(error)
        }
        wait(for: [expect], timeout: 2)
    }
}

/// Helper functions

extension BlockDownloaderTests {
    func validate(result: Result<BlockHeight, Error>, against height: BlockHeight) -> Bool {
        switch result {
        case .success(let resultHeight):
            return resultHeight == height
        default:
            return false
        }
    }
}
