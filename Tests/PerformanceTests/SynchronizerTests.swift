//
//  SynchronizerTests.swift
//  
//
//  Created by Lukáš Korba on 13.12.2022.
//

import XCTest
@testable import ZcashLightClientKit
@testable import TestUtils

class SynchronizerTests: XCTestCase {
    class MockLatestBlockHeightProvider: LatestBlockHeightProvider {
        let birthday: BlockHeight
        
        init(birthday: BlockHeight) {
            self.birthday = birthday
        }

        func latestBlockHeight(streamer: ZcashLightClientKit.CompactTxStreamerNIOClient?) throws -> ZcashLightClientKit.BlockHeight {
            self.birthday
        }
    }

    var coordinator: TestCoordinator!

    // swiftlint:disable:next line_length
    let seedPhrase = "wish puppy smile loan doll curve hole maze file ginger hair nose key relax knife witness cannon grab despair throw review deal slush frame"
    var birthday: BlockHeight = 1_730_000

    @MainActor
    func testHundredBlocksSync() async throws {
        let derivationTool = DerivationTool(networkType: .mainnet)
        let seedData: Data = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!
        let seedBytes = [UInt8](seedData)
        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(
            seed: seedBytes,
            accountIndex: 0
        )
        let ufvk = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)
        let network = ZcashNetworkBuilder.network(for: .mainnet)
        let endpoint = LightWalletEndpoint(address: "lightwalletd.electriccoin.co", port: 9067, secure: true)

        SDKMetrics.shared.enableMetrics()
        
        for _ in 1...5 {
            let databases = TemporaryDbBuilder.build()
            let initializer = Initializer(
                cacheDbURL: databases.cacheDB,
                dataDbURL: databases.dataDB,
                pendingDbURL: databases.pendingDB,
                endpoint: endpoint,
                network: network,
                spendParamsURL: try __spendParamsURL(),
                outputParamsURL: try __outputParamsURL(),
                viewingKeys: [ufvk],
                walletBirthday: birthday,
                alias: "",
                loggerProxy: SampleLogger(logLevel: .debug)
            )
            
            try? FileManager.default.removeItem(at: databases.cacheDB)
            try? FileManager.default.removeItem(at: databases.dataDB)
            try? FileManager.default.removeItem(at: databases.pendingDB)
            
            let synchronizer = try SDKSynchronizer(initializer: initializer)
            _ = try synchronizer.prepare(with: seedBytes)
            
            let syncSyncedExpectation = XCTestExpectation(description: "synchronizerSynced Expectation")
            syncSyncedExpectation.subscribe(to: .synchronizerSynced, object: nil)
            
            let internalSyncProgress = InternalSyncProgress(storage: UserDefaults.standard)
            await internalSyncProgress.rewind(to: birthday)
            await (synchronizer.blockProcessor.service as? LightWalletGRPCService)?.latestBlockHeightProvider = MockLatestBlockHeightProvider(birthday: self.birthday + 99)
            
            try synchronizer.start()
            
            wait(for: [syncSyncedExpectation], timeout: 100)
            
            SDKMetrics.shared.cumulateReportsAndStartNewSet()
        }

        if let cumulativeSummary = SDKMetrics.shared.summarizedCumulativeReports() {
            let downloadedBlocksReport = cumulativeSummary.downloadedBlocksReport ?? .zero
            let validatedBlocksReport = cumulativeSummary.validatedBlocksReport ?? .zero
            let scannedBlocksReport = cumulativeSummary.scannedBlocksReport ?? .zero
            let enhancementReport = cumulativeSummary.enhancementReport ?? .zero
            let fetchUTXOsReport = cumulativeSummary.fetchUTXOsReport ?? .zero
            let totalSyncReport = cumulativeSummary.totalSyncReport ?? .zero

            LoggerProxy.debug("""
                testHundredBlocksSync() SUMMARY min max avg REPORT:
                downloadedBlocksTimes: min: \(downloadedBlocksReport.minTime) max: \(downloadedBlocksReport.maxTime) avg: \(downloadedBlocksReport.avgTime)
                validatedBlocksTimes: min: \(validatedBlocksReport.minTime) max: \(validatedBlocksReport.maxTime) avg: \(validatedBlocksReport.avgTime)
                scannedBlocksTimes: min: \(scannedBlocksReport.minTime) max: \(scannedBlocksReport.maxTime) avg: \(scannedBlocksReport.avgTime)
                enhancementTimes: min: \(enhancementReport.minTime) max: \(enhancementReport.maxTime) avg: \(enhancementReport.avgTime)
                fetchUTXOsTimes: min: \(fetchUTXOsReport.minTime) max: \(fetchUTXOsReport.maxTime) avg: \(fetchUTXOsReport.avgTime)
                totalSyncTimes: min: \(totalSyncReport.minTime) max: \(totalSyncReport.maxTime) avg: \(totalSyncReport.avgTime)
                """)
        }
        
        SDKMetrics.shared.disableMetrics()
    }
}
