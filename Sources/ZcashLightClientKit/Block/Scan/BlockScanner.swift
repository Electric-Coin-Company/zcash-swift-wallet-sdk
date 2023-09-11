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
    @discardableResult
    func scanBlocks(
        at range: CompactBlockRange,
        totalProgressRange: CompactBlockRange,
        didScan: @escaping (BlockHeight, UInt32) async throws -> Void
    ) async throws -> BlockHeight
}

struct BlockScannerImpl {
    let config: BlockScannerConfig
    let rustBackend: ZcashRustBackendWelding
    let transactionRepository: TransactionRepository
    let metrics: SDKMetrics
    let logger: Logger
}

extension BlockScannerImpl: BlockScanner {
    @discardableResult
    func scanBlocks(
        at range: CompactBlockRange,
        totalProgressRange: CompactBlockRange,
        didScan: @escaping (BlockHeight, UInt32) async throws -> Void
    ) async throws -> BlockHeight {
        logger.debug("Going to scan blocks in range: \(range)")
        try Task.checkCancellation()

        let scanStartHeight = range.lowerBound
        let targetScanHeight = range.upperBound

        var scannedNewBlocks = false
        var lastScannedHeight = scanStartHeight

        repeat {
            try Task.checkCancellation()

            let previousScannedHeight = lastScannedHeight
            let startHeight = previousScannedHeight + 1

            // TODO: [#576] remove this arbitrary batch size https://github.com/zcash/ZcashLightClientKit/issues/576
            let batchSize = scanBatchSize(startScanHeight: startHeight, network: config.networkType)

            let scanStartTime = Date()
            do {
                try await self.rustBackend.scanBlocks(fromHeight: Int32(startHeight), limit: batchSize)
            } catch {
                logger.debug("block scanning failed with error: \(String(describing: error))")
                throw error
            }

            let scanFinishTime = Date()

            lastScannedHeight = startHeight + Int(batchSize) - 1
            
            scannedNewBlocks = previousScannedHeight != lastScannedHeight
            if scannedNewBlocks {
                try await didScan(lastScannedHeight, batchSize)

                metrics.pushProgressReport(
                    progress: 0,
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

        return lastScannedHeight
    }

    private func scanBatchSize(startScanHeight height: BlockHeight, network: NetworkType) -> UInt32 {
        assert(config.scanningBatchSize > 0, "ZcashSDK.DefaultScanningBatch must be larger than 0!")
        guard network == .mainnet else { return UInt32(config.scanningBatchSize) }

        if height > 1_650_000 {
            // librustzcash thread saturation at a number of blocks
            // that contains 100 * num_cores Sapling outputs.
            return UInt32(max(ProcessInfo().activeProcessorCount, 10))
        }

        return UInt32(config.scanningBatchSize)
    }
}
