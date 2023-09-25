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

            let batchSize = UInt32(config.scanningBatchSize)

            let scanStartTime = Date()
            do {
                try await self.rustBackend.scanBlocks(fromHeight: Int32(startHeight), limit: batchSize)
            } catch {
                logger.debug("block scanning failed with error: \(String(describing: error))")
                throw error
            }

            let scanFinishTime = Date()

            // TODO: [#1259] potential bug when rustBackend.scanBlocks scan less blocks than batchSize,
            // https://github.com/zcash/ZcashLightClientKit/issues/1259
            lastScannedHeight = startHeight + Int(batchSize) - 1
            
            scannedNewBlocks = previousScannedHeight != lastScannedHeight
            if scannedNewBlocks {
                try await didScan(lastScannedHeight, batchSize)

                metrics.pushProgressReport(
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
}
