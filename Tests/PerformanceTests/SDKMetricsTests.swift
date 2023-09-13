//
//  SDKMetricsTests.swift
//  
//
//  Created by Lukáš Korba on 19.12.2022.
//

import XCTest
@testable import ZcashLightClientKit

final class SDKMetricsTests: XCTestCase {
    func testPushDownloadBlocksReport() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()
                
        metrics.pushProgressReport(
            start: Date(timeIntervalSinceReferenceDate: 0.0),
            end: Date(timeIntervalSinceReferenceDate: 1.0),
            batchSize: 10,
            operation: .downloadBlocks
        )

        XCTAssertTrue(metrics.popBlock(operation: .downloadBlocks)?.count == 1)
        
        if let reports = metrics.reports[.downloadBlocks], let report = reports.first {
            XCTAssertEqual(report, SDKMetrics.BlockMetricReport.placeholderA)
        } else {
            XCTFail("Not expected to fail.")
        }
        
        metrics.disableMetrics()
    }
    
    func testPopDownloadBlocksReport() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        
        if let reports = metrics.popBlock(operation: .downloadBlocks), let report = reports.first {
            XCTAssertEqual(report, SDKMetrics.BlockMetricReport.placeholderA)
        } else {
            XCTFail("Not expected to fail.")
        }
        
        metrics.disableMetrics()
    }

    func testCumulativeSummary() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 1.0, avgTime: 1.0),
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        
        XCTAssertEqual(summary, metrics.cumulativeSummary())

        metrics.disableMetrics()
    }

    func testCumulateAndStartNewSet() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        metrics.cumulateReportsAndStartNewSet()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        metrics.cumulateReportsAndStartNewSet()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        metrics.cumulateReportsAndStartNewSet()

        XCTAssertTrue(metrics.cumulativeSummaries.count == 3)
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 1.0, avgTime: 1.0),
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        let summaries = [summary, summary, summary]

        XCTAssertEqual(summaries, metrics.cumulativeSummaries)

        metrics.disableMetrics()
    }
    
    func testCumulativeSummaryMinMaxAvg() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA, SDKMetrics.BlockMetricReport.placeholderB]
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 6.0, avgTime: 3.5),
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        
        XCTAssertEqual(summary, metrics.cumulativeSummary())

        metrics.disableMetrics()
    }
    
    func testSummarizedCumulativeReports() throws {
        let metrics = SDKMetrics()
        metrics.enableMetrics()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        metrics.cumulateReportsAndStartNewSet()

        metrics.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderB]
        metrics.cumulateReportsAndStartNewSet()

        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 6.0, avgTime: 3.5),
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )

        XCTAssertEqual(metrics.summarizedCumulativeReports(), summary)

        metrics.disableMetrics()
    }
}

extension SDKMetrics.BlockMetricReport {
    static let placeholderA = Self(
        batchSize: 10,
        startTime: Date(timeIntervalSinceReferenceDate: 0.0).timeIntervalSinceReferenceDate,
        endTime: Date(timeIntervalSinceReferenceDate: 1.0).timeIntervalSinceReferenceDate
    )
    
    static let placeholderB = Self(
        batchSize: 10,
        startTime: Date(timeIntervalSinceReferenceDate: 0.0).timeIntervalSinceReferenceDate,
        endTime: Date(timeIntervalSinceReferenceDate: 6.0).timeIntervalSinceReferenceDate
    )
}
