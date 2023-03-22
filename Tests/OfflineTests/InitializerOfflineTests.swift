//
//  InitializerOfflineTests.swift
//  
//
//  Created by Michal Fousek on 24.03.2023.
//

import Foundation
@testable import TestUtils
import XCTest
@testable import ZcashLightClientKit

class InitializerOfflineTests: XCTestCase {
    let validFileURL = URL(fileURLWithPath: "/some/valid/path/to.file")
    let validDirectoryURL = URL(fileURLWithPath: "/some/valid/path/to/directory")
    let invalidPathURL = URL(string: "https://whatever")!

    // MARK: - Utils

    private func makeInitializer(
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        spendParamsURL: URL,
        outputParamsURL: URL,
        alias: ZcashSynchronizerAlias
    ) -> Initializer {
        return Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: LightWalletEndpointBuilder.default,
            network: ZcashNetworkBuilder.network(for: .testnet),
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: .default,
            alias: alias,
            logLevel: .debug
        )
    }

    private func update(url: URL, with alias: ZcashSynchronizerAlias) -> URL {
        guard alias != .default else { return url }
        let lastPathComponent = url.lastPathComponent
        guard !lastPathComponent.isEmpty else { return url }
        return url
            .deletingLastPathComponent()
            .appendingPathComponent("\(alias.description)_\(lastPathComponent)")
    }

    // MARK: - Tests

    private func genericTestForURLsParsingFailures(
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        spendParamsURL: URL,
        outputParamsURL: URL,
        alias: ZcashSynchronizerAlias,
        function: String = #function
    ) {
        let initializer = makeInitializer(
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            alias: alias
        )

        if let error = initializer.urlsParsingError, case let .cantUpdateURLWithAlias(failedURL) = error {
            XCTAssertEqual(failedURL, invalidPathURL, "Failing \(function)")
        } else {
            XCTFail("URLs parsing error expected. Failing \(function)")
        }

        XCTAssertEqual(initializer.fsBlockDbRoot, fsBlockDbRoot, "Failing \(function)")
        XCTAssertEqual(initializer.dataDbURL, dataDbURL, "Failing \(function)")
        XCTAssertEqual(initializer.pendingDbURL, pendingDbURL, "Failing \(function)")
        XCTAssertEqual(initializer.spendParamsURL, spendParamsURL, "Failing \(function)")
        XCTAssertEqual(initializer.outputParamsURL, outputParamsURL, "Failing \(function)")
    }

    func test__defaultAlias__validURLs__updatedURLsAreBackwardsCompatible() {
        let initializer = makeInitializer(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .default
        )

        XCTAssertNil(initializer.urlsParsingError)
        XCTAssertEqual(initializer.fsBlockDbRoot, validDirectoryURL)
        XCTAssertEqual(initializer.dataDbURL, validFileURL)
        XCTAssertEqual(initializer.pendingDbURL, validFileURL)
        XCTAssertEqual(initializer.spendParamsURL, validFileURL)
        XCTAssertEqual(initializer.outputParamsURL, validFileURL)
    }

    func test__defaultAlias__invalidFsBlockDbRootURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: invalidPathURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .default
        )
    }

    func test__defaultAlias__invalidDataDbURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: invalidPathURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .default
        )
    }

    func test__defaultAlias__invalidPendingDbURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: invalidPathURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .default
        )
    }

    func test__defaultAlias__invalidSpendParamsURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: invalidPathURL,
            outputParamsURL: validFileURL,
            alias: .default
        )
    }

    func test__defaultAlias__invalidOutputParamsURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: invalidPathURL,
            alias: .default
        )
    }

    func test__customAlias__validURLs__updatedURLsAreAsExpected() {
        let alias: ZcashSynchronizerAlias = .custom("alias")
        let initializer = makeInitializer(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: alias
        )

        XCTAssertNil(initializer.urlsParsingError)
        XCTAssertEqual(initializer.fsBlockDbRoot, update(url: validDirectoryURL, with: alias))
        XCTAssertEqual(initializer.dataDbURL, update(url: validFileURL, with: alias))
        XCTAssertEqual(initializer.pendingDbURL, update(url: validFileURL, with: alias))
        XCTAssertEqual(initializer.spendParamsURL, update(url: validFileURL, with: alias))
        XCTAssertEqual(initializer.outputParamsURL, update(url: validFileURL, with: alias))
    }

    func test__customAlias__invalidFsBlockDbRootURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: invalidPathURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .custom("alias")
        )
    }

    func test__customAlias__invalidDataDbURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: invalidPathURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .custom("alias")
        )
    }

    func test__customAlias__invalidPendingDbURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: invalidPathURL,
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            alias: .custom("alias")
        )
    }

    func test__customAlias__invalidSpendParamsURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: invalidPathURL,
            outputParamsURL: validFileURL,
            alias: .custom("alias")
        )
    }

    func test__customAlias__invalidOutputParamsURL__errorIsGenerated() {
        genericTestForURLsParsingFailures(
            fsBlockDbRoot: validDirectoryURL,
            dataDbURL: validFileURL,
            pendingDbURL: validFileURL,
            spendParamsURL: validFileURL,
            outputParamsURL: invalidPathURL,
            alias: .custom("alias")
        )
    }
}
