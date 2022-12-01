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
        try await compactBlockBatchScanning(range: range) { [weak self] lastScannedHeight in
            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: lastScannedHeight
            )
            await self?.notifyProgress(.syncing(progress))
        }
    }


    func compactBlockBatchScanning(range: CompactBlockRange, didScan: ((BlockHeight) async -> Void)? = nil) async throws {
        try Task.checkCancellation()
        
        // TODO: remove this arbitrary batch size https://github.com/zcash/ZcashLightClientKit/issues/576
        let batchSize = scanBatchSize(for: range, network: self.config.network.networkType)
        
        do {
            if batchSize == 0 {
                let scanStartTime = Date()
                guard self.rustBackend.scanBlocks(dbCache: config.cacheDb, dbData: config.dataDb, limit: batchSize, networkType: config.network.networkType) else {
                    let error: Error = rustBackend.lastError() ?? CompactBlockProcessorError.unknown
                    LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
                    throw error
                }
                let scanFinishTime = Date()
                NotificationSender.default.post(notification:
                    SDKMetrics.progressReportNotification(
                        progress: BlockProgress(
                            startHeight: range.lowerBound,
                            targetHeight: range.upperBound,
                            progressHeight: range.upperBound
                        ),
                        start: scanStartTime,
                        end: scanFinishTime,
                        batchSize: Int(batchSize),
                        task: .scanBlocks
                    )
                )
                let seconds = scanFinishTime.timeIntervalSinceReferenceDate - scanStartTime.timeIntervalSinceReferenceDate
                LoggerProxy.debug("Scanned \(range.count) blocks in \(seconds) seconds")
            } else {
                let scanStartHeight = try transactionRepository.lastScannedHeight()
                let targetScanHeight = range.upperBound
                
                var scannedNewBlocks = false
                var lastScannedHeight = scanStartHeight
                
                repeat {
                    try Task.checkCancellation()
                    
                    let previousScannedHeight = lastScannedHeight
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
            }
        } catch {
            LoggerProxy.debug("block scanning failed with error: \(String(describing: error))")
            throw error
        }
    }

    fileprivate func scanBatchSize(for range: CompactBlockRange, network: NetworkType) -> UInt32 {
        guard network == .mainnet else {
            return UInt32(config.scanningBatchSize)
        }
        if range.lowerBound > 1_600_000 {
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

public enum SDKMetrics {
    public struct BlockMetricReport {
        public var startHeight: BlockHeight
        public var progressHeight: BlockHeight
        public var targetHeight: BlockHeight
        public var batchSize: Int
        public var duration: TimeInterval
        public var task: TaskReported
    }
    
    public enum TaskReported: String {
        case scanBlocks
    }

    public static let startBlockHeightKey = "SDKMetrics.startBlockHeightKey"
    public static let targetBlockHeightKey = "SDKMetrics.targetBlockHeightKey"
    public static let progressHeightKey = "SDKMetrics.progressHeight"
    public static let batchSizeKey = "SDKMetrics.batchSize"
    public static let startDateKey = "SDKMetrics.startDateKey"
    public static let endDateKey = "SDKMetrics.endDateKey"
    public static let taskReportedKey = "SDKMetrics.taskReported"
    public static let notificationName = Notification.Name("SDKMetrics.Notification")

    
    public static func blockReportFromNotification(_ notification: Notification) -> BlockMetricReport? {
        guard
            notification.name == notificationName,
            let info = notification.userInfo,
            let startHeight = info[startBlockHeightKey] as? BlockHeight,
            let progressHeight = info[progressHeightKey] as? BlockHeight,
            let targetHeight = info[targetBlockHeightKey] as? BlockHeight,
            let batchSize = info[batchSizeKey] as? Int,
            let task = info[taskReportedKey] as? TaskReported,
            let startDate = info[startDateKey] as? Date,
            let endDate = info[endDateKey] as? Date

        else {
            return nil
        }
        
        return BlockMetricReport(
            startHeight: startHeight,
            progressHeight: progressHeight,
            targetHeight: targetHeight,
            batchSize: batchSize,
            duration: abs(
                startDate.timeIntervalSinceReferenceDate - endDate.timeIntervalSinceReferenceDate
            ),
            task: task
        )
    }
    
    static func progressReportNotification(
        progress: BlockProgress,
        start: Date,
        end: Date,
        batchSize: Int,
        task: SDKMetrics.TaskReported
    ) -> Notification {
        var notification = Notification(name: notificationName)
        notification.userInfo = [
            startBlockHeightKey: progress.startHeight,
            targetBlockHeightKey: progress.targetHeight,
            progressHeightKey: progress.progressHeight,
            startDateKey: start,
            endDateKey: end,
            batchSizeKey: batchSize,
            taskReportedKey: task
        ]
        
        return notification
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: SDKMetrics.BlockMetricReport) {
        let literal = "\(value.task) - \(abs(value.startHeight - value.targetHeight)) processed on \(value.duration) seconds"
        appendLiteral(literal)
    }
}
