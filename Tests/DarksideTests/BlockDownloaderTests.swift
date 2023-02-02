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

// swiftlint:disable implicitly_unwrapped_optional force_cast
class BlockDownloaderTests: XCTestCase {
    let branchID = "2bb40e60"
    let chainName = "main"
    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()
    var darksideWalletService: DarksideWalletService!
    var downloader: BlockDownloaderService!
    var service: LightWalletService!
    var storage: CompactBlockRepository!
    var network = DarksideWalletDNetwork()

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = LightWalletGRPCService(endpoint: LightWalletEndpointBuilder.default)
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
        storage = FSCompactBlockRepository(
            cacheDirectory: testTempDirectory,
            metadataStore: FSMetadataStore.live(fsBlockDbRoot: testTempDirectory, rustBackend: ZcashRustBackend.self),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )
        downloader = BlockDownloaderServiceImpl(service: service, storage: storage)
        darksideWalletService = DarksideWalletService(service: service as! LightWalletGRPCService)
        
        try FakeChainBuilder.buildChain(darksideWallet: darksideWalletService, branchID: branchID, chainName: chainName)
        try darksideWalletService.applyStaged(nextLatestHeight: 663250)

        sleep(2)
    }
    
    override func tearDown() {
        super.tearDown()
        try? testFileManager.removeItem(at: testTempDirectory)
        service = nil
        storage = nil
        downloader = nil
    }
    
    func testSmallDownloadAsync() async {
        let lowerRange: BlockHeight = self.network.constants.saplingActivationHeight
        let upperRange: BlockHeight = self.network.constants.saplingActivationHeight + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange, upperRange))
        do {
            try await downloader.downloadBlockRange(range)
            
            // check what was 'stored'
            let latestHeight = await self.storage.latestHeightAsync()
            XCTAssertEqual(latestHeight, upperRange)
            
            let resultHeight = try await self.downloader.lastDownloadedBlockHeightAsync()
            XCTAssertEqual(resultHeight, upperRange)
        } catch {
            XCTFail("testSmallDownloadAsync() shouldn't fail")
        }
    }
    
    func testFailure() async {
        let awfulDownloader = BlockDownloaderServiceImpl(
            service: AwfulLightWalletService(
                latestBlockHeight: self.network.constants.saplingActivationHeight + 1000,
                service: darksideWalletService
            ),
            storage: ZcashConsoleFakeStorage()
        )
        
        let lowerRange: BlockHeight = self.network.constants.saplingActivationHeight
        let upperRange: BlockHeight = self.network.constants.saplingActivationHeight + 99
        
        let range = CompactBlockRange(uncheckedBounds: (lowerRange, upperRange))

        do {
            try await awfulDownloader.downloadBlockRange(range)
        } catch {
            XCTAssertNotNil(error)
        }
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
