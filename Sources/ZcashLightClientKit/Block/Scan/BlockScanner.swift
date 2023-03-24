//
//  CompactBlockProcessing.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
import Foundation

struct BlockScannerConfig {
    let fsBlockCacheRoot: URL
    let dataDB: URL
    let networkType: NetworkType
    let scanningBatchSize: Int
}

protocol BlockScanner {
    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: @escaping (BlockHeight) async -> Void) async throws
}

struct BlockScannerImpl {
    let config: BlockScannerConfig
    let rustBackend: ZcashRustBackendWelding.Type
    let transactionRepository: TransactionRepository
    let metrics: SDKMetrics
}

extension BlockScannerImpl: BlockScanner {
    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: @escaping (BlockHeight) async -> Void) async throws {
        try Task.checkCancellation()

        let scanStartHeight = try transactionRepository.lastScannedHeight()
        let targetScanHeight = range.upperBound

        var scannedNewBlocks = false
        var lastScannedHeight = scanStartHeight

        repeat {
            try Task.checkCancellation()

            let previousScannedHeight = lastScannedHeight

            // TODO: [#576] remove this arbitrary batch size https://github.com/zcash/ZcashLightClientKit/issues/576
            let batchSize = scanBatchSize(startScanHeight: previousScannedHeight + 1, network: self.config.networkType)

            let scanStartTime = Date()
            guard self.rustBackend.scanBlocks(
                fsBlockDbRoot: config.fsBlockCacheRoot,
                dbData: config.dataDB,
                limit: batchSize,
                networkType: config.networkType
            ) else {
                let error: Error = rustBackend.lastError() ?? CompactBlockProcessorError.unknown
                LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
                throw error
            }
            let scanFinishTime = Date()

            lastScannedHeight = try transactionRepository.lastScannedHeight()

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
                LoggerProxy.debug("Scanned \(heightCount) blocks in \(seconds) seconds")
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
