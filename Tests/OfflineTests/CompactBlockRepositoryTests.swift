//
//  CompactBlockStorageTests.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
@testable import TestUtils
@testable import ZcashLightClientKit
import XCTest

class CompactBlockRepositoryTests: XCTestCase {
    let network = ZcashNetworkBuilder.network(for: .testnet)
    let testFileManager = FileManager()
    var rustBackend: ZcashRustBackendWelding!
    var testTempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testTempDirectory = Environment.uniqueTestTempDirectory
        try self.testFileManager.createDirectory(at: testTempDirectory, withIntermediateDirectories: false)
        rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: .testnet)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
        rustBackend = nil
        testTempDirectory = nil
    }

    func testEmptyStorage() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await compactBlockRepository.create()

        let latestHeight = await compactBlockRepository.latestHeight()
        XCTAssertEqual(latestHeight, BlockHeight.empty())
    }
    
    func testStoreThousandBlocks() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await compactBlockRepository.create()

        let initialHeight = await compactBlockRepository.latestHeight()
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        
        let latestHeight = await compactBlockRepository.latestHeight()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
    }
    
    func testStoreOneBlockFromEmpty() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await compactBlockRepository.create()

        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create random block with height: \(expectedHeight)")
            return
        }
        try await compactBlockRepository.write(blocks: [block])
        
        let result = await compactBlockRepository.latestHeight()
        XCTAssertEqual(result, expectedHeight)
    }
    
    func testRewindTo() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: rustBackend,
                logger: logger
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted,
            logger: logger
        )

        try await compactBlockRepository.create()

        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        try await compactBlockRepository.rewind(to: rewindHeight)
        let latestHeight = await compactBlockRepository.latestHeight()
        XCTAssertEqual(latestHeight, rewindHeight)
    }
}
