//
//  SDKMetrics.swift
//  
//
//  Created by Lukáš Korba on 13.12.2022.
//

import Foundation

/// SDK's tool for the measurement of metrics.
/// The barebone API of the `SDKMetrics` is all about turning it on/off, pushing new reports in and popping RAW data out.
/// The processing of data is either left to the user of `SDKMetrics` or anybody can take an advantage of extension APIs
/// providing useful structs and reports.
///
/// Usage:
/// The `SDKMetrics` API has been designed so it has the lowest impact possible on the SDK itself.
/// Reporting of the metrics is already in place but ignored until `enableMetrics()` is called. Once turned on, the data is collected
/// and cumulated to the in memory structural storage until `disableMetrics()` is called.
/// `disableMetrics()` also clears out the in memory storage.
///
/// To collect data and process it there are 2 ways:
///
/// 1.
/// Get RAW data by calling either `popBlock` or `popAllBlockReports`. The post-processing of data is then delegated to the caller.
///
/// 2.
/// Get cumulated data by using an extension APIs. For the summarized collection, call `cumulativeSummary()`.
/// Sometimes, typically when you want to run several iterations, the `cumulateReportsAndStartNewSet()` automatically computes
/// cumulativeSummary, stores it and starts to collect a new set. All summaries can be either processed by a caller,
/// accessing the collection `cumulativeSummaries` directly or values can be merged into one final summary by calling `summarizedCumulativeReports()`.
///
/// We encourage you to check`SDKMetricsTests` and other tests in the Test/PerformanceTests/ folder.
public class SDKMetrics {
    public struct BlockMetricReport: Equatable {
        public let startHeight: BlockHeight
        public let progressHeight: BlockHeight
        public let targetHeight: BlockHeight
        public let batchSize: Int
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public var duration: TimeInterval { endTime - startTime }
    }
    
    public enum Operation {
        case downloadBlocks
        case validateBlocks
        case scanBlocks
        case enhancement
        case fetchUTXOs
    }
    
    public struct SyncReport: Equatable {
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public var duration: TimeInterval { endTime - startTime }
    }
    
    public var cumulativeSummaries: [CumulativeSummary] = []
    public var syncReport: SyncReport?
    var isEnabled = false
    var reports: [Operation: [BlockMetricReport]] = [:]

    public init() { }
    
    /// `SDKMetrics` is disabled by default. Any pushed data are simply ignored until `enableMetrics()` is called.
    public func enableMetrics() {
        isEnabled = true
    }
    
    public func disableMetrics() {
        isEnabled = false
        clearAll()
    }
    
    /// `SDKMetrics` focuses deeply on sync process and metrics related to it. By default there are reports around
    /// block operations like download, validate, etc. This method pushes data on a stack for the specific operation.
    func pushProgressReport(
        progress: BlockProgress,
        start: Date,
        end: Date,
        batchSize: Int,
        operation: Operation
    ) {
        guard isEnabled else { return }
        
        let blockMetricReport = BlockMetricReport(
            startHeight: progress.startHeight,
            progressHeight: progress.progressHeight,
            targetHeight: progress.targetHeight,
            batchSize: batchSize,
            startTime: start.timeIntervalSinceReferenceDate,
            endTime: end.timeIntervalSinceReferenceDate
        )
        
        guard reports[operation] != nil else {
            reports[operation] = [blockMetricReport]
            return
        }
        
        reports[operation]?.append(blockMetricReport)
    }
    
    /// Block synchronisation consists of operations but the whole process is measured also, represented by
    /// different struct `SyncReport`, missing specifics for the operations like batch size, etc.
    /// Used for the total syncing time report in the first place.
    func pushSyncReport(
        start: Date,
        end: Date
    ) {
        guard isEnabled else { return }
        
        let syncReport = SyncReport(
            startTime: start.timeIntervalSinceReferenceDate,
            endTime: end.timeIntervalSinceReferenceDate
        )
        
        self.syncReport = syncReport
    }
    
    /// A method allowing users of the `SDKMetrics` to pop the RAW data out of the system. For the specific `operation`
    /// with option to either leave data in the storage or flushing it out and start the next batch of collecting new ones.
    public func popBlock(operation: Operation, flush: Bool = false) -> [BlockMetricReport]? {
        defer {
            if flush { clearReport(operation) }
        }
        
        return reports[operation]
    }
    
    /// A method allowing users of the `SDKMetrics` to pop the RAW data out of the system. This time for all measured operations
    /// with option to either leave data in the storage or flushing it out and start the next batch of collecting new ones.
    public func popAllBlockReports(flush: Bool = false) -> [Operation: [BlockMetricReport]] {
        defer {
            if flush { clearAllBlockReports() }
        }
        
        return reports
    }
    
    func clearReport(_ operation: Operation) {
        reports.removeValue(forKey: operation)
    }
        
    func clearAllBlockReports() {
        reports.removeAll()
        cumulativeSummaries.removeAll()
    }
    
    func clearAll() {
        clearAllBlockReports()
        syncReport = nil
    }
}

/// This extension provides an API that provides the summary and accumulated reports.
/// The RAW data can pulled out and be processed without this extension but we
/// wanted to provide a way how to get essential summaries right from the SDK.
extension SDKMetrics {
    public struct CumulativeSummary: Equatable {
        public let downloadedBlocksReport: ReportSummary?
        public let validatedBlocksReport: ReportSummary?
        public let scannedBlocksReport: ReportSummary?
        public let enhancementReport: ReportSummary?
        public let fetchUTXOsReport: ReportSummary?
        public let totalSyncReport: ReportSummary?
    }

    public struct ReportSummary: Equatable {
        public let minTime: TimeInterval
        public let maxTime: TimeInterval
        public let avgTime: TimeInterval
        
        public static let zero = Self(minTime: 0, maxTime: 0, avgTime: 0)
    }

    /// This method takes all the RAW data and computes a `CumulativeSummary` for every `operation`
    /// independently. A `ReportSummary` is the result per `operation`, providing min, max and avg times.
    public func cumulativeSummary() -> CumulativeSummary {
        let downloadReport = summaryFor(reports: reports[.downloadBlocks])
        let validateReport = summaryFor(reports: reports[.validateBlocks])
        let scanReport = summaryFor(reports: reports[.scanBlocks])
        let enhancementReport = summaryFor(reports: reports[.enhancement])
        let fetchUTXOsReport = summaryFor(reports: reports[.fetchUTXOs])
        var totalSyncReport: ReportSummary?
        
        if let duration = syncReport?.duration {
            totalSyncReport = ReportSummary(minTime: duration, maxTime: duration, avgTime: duration)
        }
        
        return CumulativeSummary(
            downloadedBlocksReport: downloadReport,
            validatedBlocksReport: validateReport,
            scannedBlocksReport: scanReport,
            enhancementReport: enhancementReport,
            fetchUTXOsReport: fetchUTXOsReport,
            totalSyncReport: totalSyncReport
        )
    }
    
    /// This method computes the `CumulativeSummary` for the RAW data already in the system, stores it
    /// and leave room for collecting new RAW data. Typical use case is when some code is expected to run several times
    /// and every run is expected to be a new data collection.
    /// Usage of this API is then typically followed by calling `summarizedCumulativeReports()` which merges all stored
    /// cumulative reports into one final report.
    public func cumulateReportsAndStartNewSet() {
        cumulativeSummaries.append(cumulativeSummary())
        reports.removeAll()
        syncReport = nil
    }

    /// This method takes all `CumulativeSummary` reports and merge them all together, providing
    /// final `CumulativeSummary` per `operation`, ensuring right min and max values are in the place
    /// as well as computes final avg time per `operation`.
    public func summarizedCumulativeReports() -> CumulativeSummary? {
        var finalSummary: CumulativeSummary?
        
        cumulativeSummaries.forEach { summary in
            finalSummary = CumulativeSummary(
                downloadedBlocksReport: accumulate(left: finalSummary?.downloadedBlocksReport, right: summary.downloadedBlocksReport),
                validatedBlocksReport: accumulate(left: finalSummary?.validatedBlocksReport, right: summary.validatedBlocksReport),
                scannedBlocksReport: accumulate(left: finalSummary?.scannedBlocksReport, right: summary.scannedBlocksReport),
                enhancementReport: accumulate(left: finalSummary?.enhancementReport, right: summary.enhancementReport),
                fetchUTXOsReport: accumulate(left: finalSummary?.fetchUTXOsReport, right: summary.fetchUTXOsReport),
                totalSyncReport: accumulate(left: finalSummary?.totalSyncReport, right: summary.totalSyncReport)
            )
        }
        
        return finalSummary
    }
    
    /// Internal helper method that accumulates `ReportSummary` times.
    func accumulate(left: ReportSummary?, right: ReportSummary?) -> ReportSummary? {
        guard let left, let right else {
            if let right {
                return ReportSummary(
                    minTime: right.minTime,
                    maxTime: right.maxTime,
                    avgTime: right.avgTime
                )
            }
            return nil
        }
        
        return ReportSummary(
            minTime: min(left.minTime, right.minTime),
            maxTime: max(left.maxTime, right.maxTime),
            avgTime: (left.avgTime + right.avgTime) * 0.5
        )
    }

    /// Internal helper method that computes min, max and avg times for the `BlockMetricReport` collection.
    func summaryFor(reports: [BlockMetricReport]?) -> ReportSummary? {
        guard let reports, !reports.isEmpty else { return nil }
        
        var min: TimeInterval = 99999999.0
        var max: TimeInterval = 0.0
        var avg: TimeInterval = 0.0

        reports.forEach { report in
            let duration = report.duration
            avg += duration
            if duration > max { max = duration }
            if duration < min { min = duration }
        }
        // reports.count is guarded to never be a zero
        avg /= TimeInterval(reports.count)
        
        return ReportSummary(minTime: min, maxTime: max, avgTime: avg)
    }
}
