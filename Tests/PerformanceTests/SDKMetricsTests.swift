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
        SDKMetrics.shared.enableMetrics()
                
        SDKMetrics.shared.pushProgressReport(
            progress: BlockProgress(
                startHeight: 1_730_000,
                targetHeight: 1_730_099,
                progressHeight: 1_730_050
            ),
            start: Date(timeIntervalSinceReferenceDate: 0.0),
            end: Date(timeIntervalSinceReferenceDate: 1.0),
            batchSize: 10,
            operation: .downloadBlocks
        )

        XCTAssertTrue(SDKMetrics.shared.popBlock(operation: .downloadBlocks)?.count == 1)
        
        if let reports = SDKMetrics.shared.reports[.downloadBlocks], let report = reports.first {
            XCTAssertEqual(report, SDKMetrics.BlockMetricReport.placeholderA)
        } else {
            XCTFail()
        }
        
        SDKMetrics.shared.disableMetrics()
    }
    
    func testPopDownloadBlocksReport() throws {
        SDKMetrics.shared.enableMetrics()
           
        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        
        if let reports = SDKMetrics.shared.popBlock(operation: .downloadBlocks), let report = reports.first {
            XCTAssertEqual(report, SDKMetrics.BlockMetricReport.placeholderA)
        } else {
            XCTFail()
        }
        
        SDKMetrics.shared.disableMetrics()
    }

    func testCumulativeSummary() throws {
        SDKMetrics.shared.enableMetrics()
           
        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 1.0, avgTime: 1.0),
            validatedBlocksReport: nil,
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        
        XCTAssertEqual(summary, SDKMetrics.shared.cumulativeSummary())

        SDKMetrics.shared.disableMetrics()
    }

    func testCumulateAndStartNewSet() throws {
        SDKMetrics.shared.enableMetrics()
           
        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        SDKMetrics.shared.cumulateReportsAndStartNewSet()

        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        SDKMetrics.shared.cumulateReportsAndStartNewSet()

        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        SDKMetrics.shared.cumulateReportsAndStartNewSet()

        XCTAssertTrue(SDKMetrics.shared.cumulativeSummaries.count == 3)
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 1.0, avgTime: 1.0),
            validatedBlocksReport: nil,
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        let summaries = [summary, summary, summary]

        XCTAssertEqual(summaries, SDKMetrics.shared.cumulativeSummaries)

        SDKMetrics.shared.disableMetrics()
    }
    
    func testCumulativeSummaryMinMaxAvg() throws {
        SDKMetrics.shared.enableMetrics()
           
        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA, SDKMetrics.BlockMetricReport.placeholderB]
        
        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 6.0, avgTime: 3.5),
            validatedBlocksReport: nil,
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )
        
        XCTAssertEqual(summary, SDKMetrics.shared.cumulativeSummary())

        SDKMetrics.shared.disableMetrics()
    }
    
    func testSummarizedCumulativeReports() throws {
        SDKMetrics.shared.enableMetrics()
           
        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderA]
        SDKMetrics.shared.cumulateReportsAndStartNewSet()

        SDKMetrics.shared.reports[.downloadBlocks] = [SDKMetrics.BlockMetricReport.placeholderB]
        SDKMetrics.shared.cumulateReportsAndStartNewSet()

        let summary = SDKMetrics.CumulativeSummary(
            downloadedBlocksReport: SDKMetrics.ReportSummary(minTime: 1.0, maxTime: 6.0, avgTime: 3.5),
            validatedBlocksReport: nil,
            scannedBlocksReport: nil,
            enhancementReport: nil,
            fetchUTXOsReport: nil,
            totalSyncReport: nil
        )

        XCTAssertEqual(SDKMetrics.shared.summarizedCumulativeReports(), summary)

        SDKMetrics.shared.disableMetrics()
    }
}

extension SDKMetrics.BlockMetricReport {
    static let placeholderA = Self(
        startHeight: 1_730_000,
        progressHeight: 1_730_050,
        targetHeight: 1_730_099,
        batchSize: 10,
        startTime: Date(timeIntervalSinceReferenceDate: 0.0).timeIntervalSinceReferenceDate,
        endTime: Date(timeIntervalSinceReferenceDate: 1.0).timeIntervalSinceReferenceDate
    )
    
    static let placeholderB = Self(
        startHeight: 1_730_000,
        progressHeight: 1_730_080,
        targetHeight: 1_730_099,
        batchSize: 10,
        startTime: Date(timeIntervalSinceReferenceDate: 0.0).timeIntervalSinceReferenceDate,
        endTime: Date(timeIntervalSinceReferenceDate: 6.0).timeIntervalSinceReferenceDate
    )
}
