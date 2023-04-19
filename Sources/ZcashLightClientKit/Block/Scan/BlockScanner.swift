//
//  CompactBlockProcessing.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
import Foundation

struct BlockScannerConfig {
    let networkType: NetworkType
    let scanningBatchSize: Int
}

protocol BlockScanner {
    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: @escaping (BlockHeight) async -> Void) async throws
}

struct BlockScannerImpl {
    let config: BlockScannerConfig
    let rustBackend: ZcashRustBackendWelding
    let transactionRepository: TransactionRepository
    let metrics: SDKMetrics
    let logger: Logger
    let latestBlocksDataProvider: LatestBlocksDataProvider
}

extension BlockScannerImpl: BlockScanner {
    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: @escaping (BlockHeight) async -> Void) async throws {
        try Task.checkCancellation()

        let scanStartHeight = try await transactionRepository.lastScannedHeight()
        let targetScanHeight = range.upperBound

        var scannedNewBlocks = false
        var lastScannedHeight = scanStartHeight

        repeat {
            try Task.checkCancellation()

            let previousScannedHeight = lastScannedHeight

            // TODO: [#576] remove this arbitrary batch size https://github.com/zcash/ZcashLightClientKit/issues/576
            let batchSize = scanBatchSize(startScanHeight: previousScannedHeight + 1, network: config.networkType)

            let scanStartTime = Date()
            do {
                try await self.rustBackend.scanBlocks(limit: batchSize)
            } catch {
                logger.debug("block scanning failed with error: \(String(describing: error))")
                throw error
            }

            let scanFinishTime = Date()

            if let lastScannedBlock = try await transactionRepository.lastScannedBlock() {
                lastScannedHeight = lastScannedBlock.height
                await latestBlocksDataProvider.updateLatestScannedHeight(lastScannedHeight)
                await latestBlocksDataProvider.updateLatestScannedTime(TimeInterval(lastScannedBlock.time))
            }
            
            scannedNewBlocks = previousScannedHeight != lastScannedHeight
            if scannedNewBlocks {
                await didScan(lastScannedHeight)

                let progress = BlockProgress(
                    startHeight: totalProgressRange.lowerBound,
                    targetHeight: totalProgressRange.upperBound,
                    progressHeight: lastScannedHeight
                )

                metrics.pushProgressReport(
                    progress: progress,
                    start: scanStartTime,
                    end: scanFinishTime,
                    batchSize: Int(batchSize),
                    operation: .scanBlocks
                )

                let heightCount = lastScannedHeight - previousScannedHeight
                let seconds = scanFinishTime.timeIntervalSinceReferenceDate - scanStartTime.timeIntervalSinceReferenceDate
                logger.debug("Scanned \(heightCount) blocks in \(seconds) seconds")
            }

            await Task.yield()
        } while !Task.isCancelled && scannedNewBlocks && lastScannedHeight < targetScanHeight
    }

    private func scanBatchSize(startScanHeight height: BlockHeight, network: NetworkType) -> UInt32 {
        assert(config.scanningBatchSize > 0, "ZcashSDK.DefaultScanningBatch must be larger than 0!")
        guard network == .mainnet else { return UInt32(config.scanningBatchSize) }

        if height > 1_600_000 {
            return 5
        }

        return UInt32(config.scanningBatchSize)
    }
}
