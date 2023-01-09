//
//  CompactBlockProcessing.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension CompactBlockProcessor {

    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange) async throws {
        try await compactBlockBatchScanning(range: range, totalProgressRange: totalProgressRange) { [weak self] lastScannedHeight in
            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: lastScannedHeight
            )
            await self?.notifyProgress(.syncing(progress))
        }
    }

    func compactBlockBatchScanning(
        range: CompactBlockRange,
        totalProgressRange: CompactBlockRange,
        didScan: ((BlockHeight) async -> Void)? = nil
    ) async throws {
        try Task.checkCancellation()

        do {
            let scanStartHeight = try transactionRepository.lastScannedHeight()
            let targetScanHeight = range.upperBound

            var scannedNewBlocks = false
            var lastScannedHeight = scanStartHeight

            repeat {
                try Task.checkCancellation()

                let previousScannedHeight = lastScannedHeight

                // TODO: remove this arbitrary batch size https://github.com/zcash/ZcashLightClientKit/issues/576
                let batchSize = scanBatchSize(startScanHeight: previousScannedHeight + 1, network: self.config.network.networkType)

                let scanStartTime = Date()
                guard self.rustBackend.scanBlocks(
                    dbCache: config.cacheDb,
                    dbData: config.dataDb,
                    limit: batchSize,
                    networkType: config.network.networkType
                ) else {
                    let error: Error = rustBackend.lastError() ?? CompactBlockProcessorError.unknown
                    LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
                    throw error
                }
                let scanFinishTime = Date()

                lastScannedHeight = try transactionRepository.lastScannedHeight()

                scannedNewBlocks = previousScannedHeight != lastScannedHeight
                if scannedNewBlocks {
                    await didScan?(lastScannedHeight)

                    let progress = BlockProgress(
                        startHeight: totalProgressRange.lowerBound,
                        targetHeight: totalProgressRange.upperBound,
                        progressHeight: lastScannedHeight
                    )

                    SDKMetrics.shared.pushProgressReport(
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
            if Task.isCancelled {
                state = .stopped
                LoggerProxy.debug("Warning: compactBlockBatchScanning cancelled")
            }
        } catch {
            LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
            throw error
        }
    }

    fileprivate func scanBatchSize(startScanHeight height: BlockHeight, network: NetworkType) -> UInt32 {
        assert(config.scanningBatchSize > 0, "ZcashSDK.DefaultScanningBatch must be larger than 0!")
        guard network == .mainnet else {
            return UInt32(config.scanningBatchSize)
        }
        if height > 1_600_000 {
            return 5
        }

        return UInt32(config.scanningBatchSize)
    }
}

extension CompactBlockProcessor {
    func compactBlockScanning(
        rustWelding: ZcashRustBackendWelding.Type,
        cacheDb: URL,
        dataDb: URL,
        limit: UInt32 = 0,
        networkType: NetworkType
    ) throws {
        try Task.checkCancellation()
        
        guard rustBackend.scanBlocks(dbCache: cacheDb, dbData: dataDb, limit: limit, networkType: networkType) else {
            let error: Error = rustBackend.lastError() ?? CompactBlockProcessorError.unknown
            LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
            throw error
        }
    }
}
