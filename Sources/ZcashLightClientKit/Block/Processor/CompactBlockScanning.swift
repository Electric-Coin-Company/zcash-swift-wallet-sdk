//
//  CompactBlockProcessing.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension CompactBlockProcessor {
    func compactBlockBatchScanning(range: CompactBlockRange) async throws {
        try Task.checkCancellation()
        
        setState(.scanning)

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
                NotificationCenter.default.post(
                    SDKMetrics.progressReportNotification(
                        progress: BlockProgress(
                            startHeight: range.lowerBound,
                            targetHeight: range.upperBound,
                            progressHeight: range.upperBound
                        ),
                        start: scanStartTime,
                        end: scanFinishTime,
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
                        let progress = BlockProgress(startHeight: scanStartHeight, targetHeight: targetScanHeight, progressHeight: lastScannedHeight)
                        notifyProgress(.scan(progress))
                        NotificationCenter.default.post(
                            SDKMetrics.progressReportNotification(
                                progress: progress,
                                start: scanStartTime,
                                end: scanFinishTime,
                                task: .scanBlocks
                            )
                        )
                        
                        let heightCount = lastScannedHeight - previousScannedHeight
                        let seconds = scanFinishTime.timeIntervalSinceReferenceDate - scanStartTime.timeIntervalSinceReferenceDate
                        LoggerProxy.debug("Scanned \(heightCount) blocks in \(seconds) seconds")
                    }
                } while !Task.isCancelled && scannedNewBlocks && lastScannedHeight < targetScanHeight
                if Task.isCancelled {
                    setState(.stopped)
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
    struct BlockMetricReport {
        var startHeight: BlockHeight
        var targetHeight: BlockHeight
        var duration: TimeInterval
        var task: TaskReported
    }
    
    enum TaskReported: String {
        case scanBlocks
    }

    static let startBlockHeightKey = "SDKMetrics.startBlockHeightKey"
    static let targetBlockHeightKey = "SDKMetrics.targetBlockHeightKey"
    static let progressHeightKey = "SDKMetrics.progressHeight"
    static let startDateKey = "SDKMetrics.startDateKey"
    static let endDateKey = "SDKMetrics.endDateKey"
    static let taskReportedKey = "SDKMetrics.taskReported"
    static let notificationName = Notification.Name("SDKMetrics.Notification")
    
    static func blockReportFromNotification(_ notification: Notification) -> BlockMetricReport? {
        guard
            notification.name == notificationName,
            let info = notification.userInfo,
            let startHeight = info[startBlockHeightKey] as? BlockHeight,
            let targetHeight = info[targetBlockHeightKey] as? BlockHeight,
            let task = info[taskReportedKey] as? TaskReported,
            let startDate = info[startDateKey] as? Date,
            let endDate = info[endDateKey] as? Date
        else {
            return nil
        }
        
        return BlockMetricReport(
            startHeight: startHeight,
            targetHeight: targetHeight,
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
        task: SDKMetrics.TaskReported
    ) -> Notification {
        var notification = Notification(name: notificationName)
        notification.userInfo = [
            startBlockHeightKey: progress.startHeight,
            targetBlockHeightKey: progress.targetHeight,
            progressHeightKey: progress.progressHeight,
            startDateKey: start,
            endDateKey: end,
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
