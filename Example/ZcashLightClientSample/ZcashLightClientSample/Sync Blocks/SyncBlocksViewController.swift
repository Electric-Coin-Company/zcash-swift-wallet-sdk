//
//  SyncBlocksViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 11/1/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import UIKit
import ZcashLightClientKit

/// Sync blocks view controller leverages Compact Block Processor directly. This provides more detail on block processing if needed.
/// We advise to use the SDKSynchronizer first since it provides a lot of functionality out of the box.
class SyncBlocksViewController: UIViewController {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var startPause: UIButton!
    @IBOutlet weak var metricLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    
    private var queue = DispatchQueue(label: "metrics.queue", qos: .default)
    private var accumulatedMetrics: ProcessorMetrics = .initial
    private var currentMetric: SDKMetrics.Operation?
    private var currentMetricName: String {
        guard let currentMetric else { return "" }
        switch currentMetric {
        case .downloadBlocks: return "download: "
        case .validateBlocks: return "validate: "
        case .scanBlocks: return "scan: "
        case .enhancement: return "enhancement: "
        case .fetchUTXOs: return "fetchUTXOs: "
        }
    }

    let synchronizer = AppDelegate.shared.sharedSynchronizer

    var notificationCancellables: [AnyCancellable] = []

    deinit {
        notificationCancellables.forEach { $0.cancel() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        statusLabel.text = textFor(state: synchronizer.status)
        progressBar.progress = 0
        let center = NotificationCenter.default
        let subscribeToNotifications: [Notification.Name] = [
            .synchronizerStarted,
            .synchronizerProgressUpdated,
            .synchronizerStatusWillUpdate,
            .synchronizerSynced,
            .synchronizerStopped,
            .synchronizerDisconnected,
            .synchronizerSyncing,
            .synchronizerDownloading,
            .synchronizerValidating,
            .synchronizerScanning,
            .synchronizerEnhancing,
            .synchronizerFetching,
            .synchronizerFailed
        ]

        for notificationName in subscribeToNotifications {
            center.publisher(for: notificationName)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    DispatchQueue.main.async {
                        self?.processorNotification(notification)
                    }
                }
                .store(in: &notificationCancellables)
        }

        NotificationCenter.default.publisher(for: .blockProcessorStartedDownloading, object: nil)
            .sink { [weak self] _ in
                self?.currentMetric = .downloadBlocks
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .blockProcessorStartedValidating, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.accumulateMetrics()
                self?.summaryLabel.text = "download: \((self?.accumulatedMetrics.debugDescription ?? "No summary"))"
                self?.accumulatedMetrics = .initial
                self?.currentMetric = .validateBlocks
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .blockProcessorStartedScanning, object: nil)
            .sink { [weak self] _ in
                self?.currentMetric = .scanBlocks
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .blockProcessorStartedEnhancing, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.accumulateMetrics()
                self?.summaryLabel.text = "scan: \((self?.accumulatedMetrics.debugDescription ?? "No summary"))"
                self?.accumulatedMetrics = .initial
                self?.currentMetric = .enhancement
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .blockProcessorUpdated, object: nil)
            .throttle(for: 5, scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .map { [weak self] _ -> SDKMetrics.BlockMetricReport? in
                guard let currentMetric = self?.currentMetric else { return nil }
                return SDKMetrics.shared.popBlock(operation: currentMetric)?.last
            }
            .sink { [weak self] report in
                self?.metricLabel.text = (self?.currentMetricName ?? "") + report.debugDescription
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .blockProcessorFinished, object: nil)
            .receive(on: DispatchQueue.main)
            .delay(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.accumulateMetrics()
                self?.summaryLabel.text = "enhancement: \((self?.accumulatedMetrics.debugDescription ?? "No summary"))"
                self?.overallSummary()
            }
            .store(in: &notificationCancellables)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        notificationCancellables.forEach { $0.cancel() }
        synchronizer.stop()
    }

    @objc func processorNotification(_ notification: Notification) {
        self.updateUI()

        switch notification.name {
        case let not where not == Notification.Name.synchronizerProgressUpdated:
            guard let progress = notification.userInfo?[SDKSynchronizer.NotificationKeys.progress] as? CompactBlockProgress else { return }
            self.progressBar.progress = progress.progress
            self.progressLabel.text = "\(Int(floor(progress.progress * 100)))%"
        default:
            return
        }
    }
    
    func accumulateMetrics() {
        guard let currentMetric else { return }
        if let reports = SDKMetrics.shared.popBlock(operation: currentMetric) {
            for report in reports {
                accumulatedMetrics = .accumulate(accumulatedMetrics, current: report)
            }
        }
    }
    
    func overallSummary() {
        let cumulativeSummary = SDKMetrics.shared.cumulativeSummary()
        
        let downloadedBlocksReport = cumulativeSummary.downloadedBlocksReport ?? SDKMetrics.ReportSummary.zero
        let validatedBlocksReport = cumulativeSummary.validatedBlocksReport ?? SDKMetrics.ReportSummary.zero
        let scannedBlocksReport = cumulativeSummary.scannedBlocksReport ?? SDKMetrics.ReportSummary.zero
        let enhancementReport = cumulativeSummary.enhancementReport ?? SDKMetrics.ReportSummary.zero
        let fetchUTXOsReport = cumulativeSummary.fetchUTXOsReport ?? SDKMetrics.ReportSummary.zero
        let totalSyncReport = cumulativeSummary.totalSyncReport ?? SDKMetrics.ReportSummary.zero

        metricLabel.text =
            """
            Summary:
                downloadedBlocks: min: \(downloadedBlocksReport.minTime) max: \(downloadedBlocksReport.maxTime) avg: \(downloadedBlocksReport.avgTime)
                validatedBlocks: min: \(validatedBlocksReport.minTime) max: \(validatedBlocksReport.maxTime) avg: \(validatedBlocksReport.avgTime)
                scannedBlocks: min: \(scannedBlocksReport.minTime) max: \(scannedBlocksReport.maxTime) avg: \(scannedBlocksReport.avgTime)
                enhancement: min: \(enhancementReport.minTime) max: \(enhancementReport.maxTime) avg: \(enhancementReport.avgTime)
                fetchUTXOs: min: \(fetchUTXOsReport.minTime) max: \(fetchUTXOsReport.maxTime) avg: \(fetchUTXOsReport.avgTime)
                totalSync: min: \(totalSyncReport.minTime) max: \(totalSyncReport.maxTime) avg: \(totalSyncReport.avgTime)
            """
    }

    @IBAction func startStop() {
        Task { @MainActor in
            await doStartStop()
        }
    }

    func doStartStop() async {
        switch synchronizer.status {
        case .stopped, .unprepared:
            do {
                if synchronizer.status == .unprepared {
                    _ = try synchronizer.prepare(with: DemoAppConfig.seed)
                }

                SDKMetrics.shared.enableMetrics()
                try synchronizer.start()
                updateUI()
            } catch {
                loggerProxy.error("Can't start synchronizer: \(error)")
                updateUI()
            }
        default:
            synchronizer.stop()
            SDKMetrics.shared.disableMetrics()
            updateUI()
        }

        updateUI()
    }

    func fail(error: Error) {
        let alert = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)

        alert.addAction(
            UIAlertAction(
                title: "Ok",
                style: .cancel,
                handler: { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            )
        )

        self.present(alert, animated: true, completion: nil)
        updateUI()
    }

    func updateUI() {
        let state = synchronizer.status

        statusLabel.text = textFor(state: state)
        startPause.setTitle(buttonText(for: state), for: .normal)
        if case SyncStatus.synced = state {
            startPause.isEnabled = false
        } else {
            startPause.isEnabled = true
        }
    }

    func buttonText(for state: SyncStatus) -> String {
        switch state {
        case .downloading, .scanning, .validating:
            return "Pause"
        case .stopped:
            return "Start"
        case .error, .unprepared, .disconnected:
            return "Retry"
        case .synced:
            return "Chill!"
        case .enhancing:
            return "Enhance"
        case .fetching:
            return "fetch"
        }
    }

    func textFor(state: SyncStatus) -> String {
        switch state {
        case .downloading:
            return "Downloading ⛓"
        case .error:
            return "error 💔"
        case .scanning:
            return "Scanning Blocks 🤖"
        case .stopped:
            return "Stopped 🚫"
        case .validating:
            return "Validating chain 🕵️‍♀️"
        case .synced:
            return "Synced 😎"
        case .enhancing:
            return "Enhancing 🤖"
        case .fetching:
            return "Fetching UTXOs"
        case .unprepared:
            return "Unprepared"
        case .disconnected:
            return "Disconnected"
        }
    }
}

struct ProcessorMetrics {
    var minHeight: BlockHeight
    var maxHeight: BlockHeight
    var maxDuration: (TimeInterval, CompactBlockRange)
    var minDuration: (TimeInterval, CompactBlockRange)
    var cumulativeDuration: TimeInterval
    var measuredCount: Int

    var averageDuration: TimeInterval {
        measuredCount > 0 ? cumulativeDuration / Double(measuredCount) : 0
    }

    static let initial = Self.init(
        minHeight: .max,
        maxHeight: .min,
        maxDuration: (TimeInterval.leastNonzeroMagnitude, 0 ... 1),
        minDuration: (TimeInterval.greatestFiniteMagnitude, 0 ... 1),
        cumulativeDuration: 0,
        measuredCount: 0
    )

    static func accumulate(_ prev: ProcessorMetrics, current: SDKMetrics.BlockMetricReport) -> Self {
        .init(
            minHeight: min(prev.minHeight, current.startHeight),
            maxHeight: max(prev.maxHeight, current.progressHeight),
            maxDuration: compareDuration(
                prev.maxDuration,
                (current.duration, current.progressHeight - current.batchSize ... current.progressHeight),
                max
            ),
            minDuration: compareDuration(
                prev.minDuration,
                (current.duration, current.progressHeight - current.batchSize ... current.progressHeight),
                min
            ),
            cumulativeDuration: prev.cumulativeDuration + current.duration,
            measuredCount: prev.measuredCount + 1
        )
    }

    static func compareDuration(
        _ prev: (TimeInterval, CompactBlockRange),
        _ current: (TimeInterval, CompactBlockRange),
        _ cmp: (TimeInterval, TimeInterval) -> TimeInterval
    ) -> (TimeInterval, CompactBlockRange) {
        cmp(prev.0, current.0) == current.0 ? current : prev
    }
}

extension ProcessorMetrics: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        ProcessorMetrics:
            minHeight: \(self.minHeight)
            maxHeight: \(self.maxHeight)

            avg time: \(self.averageDuration)
            overall time: \(self.cumulativeDuration)
            slowest range:
                range:  \(self.maxDuration.1.description)
                count:  \(self.maxDuration.1.count)
                seconds: \(self.maxDuration.0)
            Fastest range:
                range: \(self.minDuration.1.description)
                count: \(self.minDuration.1.count)
                seconds: \(self.minDuration.0)
        """
    }
}

extension CompactBlockRange {
    var description: String {
        "\(self.lowerBound) ... \(self.upperBound)"
    }
}

extension SDKMetrics.BlockMetricReport: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        BlockMetric:
            startHeight: \(self.progressHeight - self.batchSize)
            endHeight: \(self.progressHeight)
            batchSize: \(self.batchSize)
            duration: \(self.duration)
        """
    }
}
