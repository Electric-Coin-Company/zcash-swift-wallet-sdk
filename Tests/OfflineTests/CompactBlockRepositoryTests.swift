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

    let testTempDirectory = URL(fileURLWithPath: NSString(
        string: NSTemporaryDirectory()
    )
        .appendingPathComponent("tmp-\(Int.random(in: 0 ... .max))"))

    let testFileManager = FileManager()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try self.testFileManager.createDirectory(at: self.testTempDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? testFileManager.removeItem(at: testTempDirectory)
    }

    func testEmptyStorage() throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        XCTAssertEqual(compactBlockRepository.latestHeight(), .empty())
    }

    func testEmptyStorageAsync() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let latestHeight = await compactBlockRepository.latestHeightAsync()

        XCTAssertEqual(latestHeight, BlockHeight.empty())
    }

    func testStoreThousandBlocks() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let initialHeight = await compactBlockRepository.latestHeightAsync()
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        } catch {
            XCTFail("seed failed with error: \(error)")
            return
        }
        
        let latestHeight = compactBlockRepository.latestHeight()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
    }
    
    func testStoreThousandBlocksAsync() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let initialHeight = compactBlockRepository.latestHeight()
        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        
        let latestHeight = await compactBlockRepository.latestHeightAsync()
        XCTAssertNotEqual(initialHeight, latestHeight)
        XCTAssertEqual(latestHeight, finalHeight)
    }
    
    func testStoreOneBlockFromEmpty() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()
        
        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create random block with height: \(expectedHeight)")
            return
        }

        try await compactBlockRepository.write(blocks: [block])

        XCTAssertEqual(compactBlockRepository.latestHeight(), expectedHeight)
    }
    
    func testStoreOneBlockFromEmptyAsync() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let expectedHeight = BlockHeight(123_456)
        guard let block = StubBlockCreator.createRandomDataBlock(with: expectedHeight) else {
            XCTFail("could not create random block with height: \(expectedHeight)")
            return
        }
        try await compactBlockRepository.write(blocks: [block])
        
        let result = await compactBlockRepository.latestHeightAsync()
        XCTAssertEqual(result, expectedHeight)
    }
    
    func testRewindTo() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        do {
            try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        } catch {
            XCTFail("seed failed with error: \(error)")
            return
        }
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        do {
            try await compactBlockRepository.rewindAsync(to: rewindHeight)

            XCTAssertEqual(compactBlockRepository.latestHeight(), rewindHeight)
        } catch {
            XCTFail("Rewind latest block failed with error: \(error)")
        }
    }
    
    func testRewindToAsync() async throws {
        let compactBlockRepository: CompactBlockRepository = FSCompactBlockRepository(
            fsBlockDbRoot: testTempDirectory,
            metadataStore: FSMetadataStore.live(
                fsBlockDbRoot: testTempDirectory,
                rustBackend: ZcashRustBackend.self
            ),
            blockDescriptor: .live,
            contentProvider: DirectoryListingProviders.defaultSorted
        )

        try compactBlockRepository.create()

        let startHeight = self.network.constants.saplingActivationHeight
        let blockCount = Int(1_000)
        let finalHeight = startHeight + blockCount
        
        try await TestDbBuilder.seed(db: compactBlockRepository, with: startHeight...finalHeight)
        let rewindHeight = BlockHeight(finalHeight - 233)
        
        try await compactBlockRepository.rewindAsync(to: rewindHeight)
        let latestHeight = await compactBlockRepository.latestHeightAsync()
        XCTAssertEqual(latestHeight, rewindHeight)
    }
}
