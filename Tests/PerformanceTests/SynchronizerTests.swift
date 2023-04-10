//
//  SynchronizerTests.swift
//  
//
//  Created by Lukáš Korba on 13.12.2022.
//

import Combine
import XCTest
@testable import ZcashLightClientKit
@testable import TestUtils

class SynchronizerTests: XCTestCase {
    class MockLatestBlockHeightProvider: LatestBlockHeightProvider {
        let birthday: BlockHeight
        
        init(birthday: BlockHeight) {
            self.birthday = birthday
        }

        func latestBlockHeight(streamer: CompactTxStreamerAsyncClient) async throws -> BlockHeight {
            self.birthday
        }
    }

    var coordinator: TestCoordinator!
    var cancellables: [AnyCancellable] = []
    var sdkSynchronizerSyncStatusHandler: SDKSynchronizerSyncStatusHandler! = SDKSynchronizerSyncStatusHandler()
    var rustBackend: ZcashRustBackendWelding!
    var testTempDirectory: URL!

    let seedPhrase = """
    wish puppy smile loan doll curve hole maze file ginger hair nose key relax knife witness cannon grab despair throw review deal slush frame
    """

    var birthday: BlockHeight = 1_730_000

    override func setUp() async throws {
        try await super.setUp()
        testTempDirectory = Environment.uniqueTestTempDirectory
        rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: testTempDirectory, networkType: .mainnet)
    }

    override func tearDown() {
        super.tearDown()
        coordinator = nil
        cancellables = []
        sdkSynchronizerSyncStatusHandler = nil
        rustBackend = nil
        testTempDirectory = nil
    }

    func testHundredBlocksSync() async throws {
        let derivationTool = DerivationTool(networkType: .mainnet)
        guard let seedData = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==") else {
            XCTFail("seedData expected to be successfuly instantiated.")
            return
        }
        let seedBytes = [UInt8](seedData)
        let spendingKey = try await derivationTool.deriveUnifiedSpendingKey(
            seed: seedBytes,
            accountIndex: 0
        )
        let ufvk = try await derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let endpoint = LightWalletEndpoint(address: "lightwalletd.electriccoin.co", port: 9067, secure: true)

        var synchronizer: SDKSynchronizer?
        for _ in 1...5 {
            let databases = TemporaryDbBuilder.build()
            let initializer = Initializer(
                cacheDbURL: nil,
                fsBlockDbRoot: databases.fsCacheDbRoot,
                dataDbURL: databases.dataDB,
                pendingDbURL: databases.pendingDB,
                endpoint: endpoint,
                network: network,
                spendParamsURL: try __spendParamsURL(),
                outputParamsURL: try __outputParamsURL(),
                saplingParamsSourceURL: SaplingParamsSourceURL.tests,
                alias: .default,
                logLevel: .debug
            )
            
            try? FileManager.default.removeItem(at: databases.fsCacheDbRoot)
            try? FileManager.default.removeItem(at: databases.dataDB)
            try? FileManager.default.removeItem(at: databases.pendingDB)
            
            synchronizer = SDKSynchronizer(initializer: initializer)
            
            guard let synchronizer else { fatalError("Synchronizer not initialized.") }
            
            synchronizer.metrics.enableMetrics()
            _ = try await synchronizer.prepare(with: seedBytes, viewingKeys: [ufvk], walletBirthday: birthday)
            
            let syncSyncedExpectation = XCTestExpectation(description: "synchronizerSynced Expectation")
            sdkSynchronizerSyncStatusHandler.subscribe(to: synchronizer.stateStream, expectations: [.synced: syncSyncedExpectation])
            
            let internalSyncProgress = InternalSyncProgress(
                alias: .default,
                storage: UserDefaults.standard,
                logger: logger
            )
            await internalSyncProgress.rewind(to: birthday)
            await (synchronizer.blockProcessor.service as? LightWalletGRPCService)?.latestBlockHeightProvider = MockLatestBlockHeightProvider(
                birthday: self.birthday + 99
            )
            
            try await synchronizer.start()
            
            wait(for: [syncSyncedExpectation], timeout: 100)
            
            synchronizer.metrics.cumulateReportsAndStartNewSet()
        }

        if let cumulativeSummary = synchronizer?.metrics.summarizedCumulativeReports() {
            let downloadedBlocksReport = cumulativeSummary.downloadedBlocksReport ?? .zero
            let validatedBlocksReport = cumulativeSummary.validatedBlocksReport ?? .zero
            let scannedBlocksReport = cumulativeSummary.scannedBlocksReport ?? .zero
            let enhancementReport = cumulativeSummary.enhancementReport ?? .zero
            let fetchUTXOsReport = cumulativeSummary.fetchUTXOsReport ?? .zero
            let totalSyncReport = cumulativeSummary.totalSyncReport ?? .zero

            let downloadedBlockAVGTime = downloadedBlocksReport.avgTime
            LoggerProxy.debug("""
            testHundredBlocksSync() SUMMARY min max avg REPORT:
            downloadedBlocksTimes: min: \(downloadedBlocksReport.minTime) max: \(downloadedBlocksReport.maxTime) avg: \(downloadedBlockAVGTime)
            validatedBlocksTimes: min: \(validatedBlocksReport.minTime) max: \(validatedBlocksReport.maxTime) avg: \(validatedBlocksReport.avgTime)
            scannedBlocksTimes: min: \(scannedBlocksReport.minTime) max: \(scannedBlocksReport.maxTime) avg: \(scannedBlocksReport.avgTime)
            enhancementTimes: min: \(enhancementReport.minTime) max: \(enhancementReport.maxTime) avg: \(enhancementReport.avgTime)
            fetchUTXOsTimes: min: \(fetchUTXOsReport.minTime) max: \(fetchUTXOsReport.maxTime) avg: \(fetchUTXOsReport.avgTime)
            totalSyncTimes: min: \(totalSyncReport.minTime) max: \(totalSyncReport.maxTime) avg: \(totalSyncReport.avgTime)
            """)
        }
        
        synchronizer?.metrics.disableMetrics()
    }
}
