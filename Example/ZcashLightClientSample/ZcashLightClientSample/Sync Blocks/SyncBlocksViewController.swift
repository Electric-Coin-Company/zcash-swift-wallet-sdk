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
    @IBOutlet weak var progressDataLabel: UILabel!
    @IBOutlet weak var startPause: UIButton!
    @IBOutlet weak var metricLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!

    private var queue = DispatchQueue(label: "metrics.queue", qos: .default)
    private var enhancingStarted = false
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

    var cancellables: [AnyCancellable] = []
    let dateFormatter = DateFormatter()

    let synchronizer = AppDelegate.shared.sharedSynchronizer
    let closureSynchronizer = ClosureSDKSynchronizer(synchronizer: AppDelegate.shared.sharedSynchronizer)

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(wipe(_:))
        )

        statusLabel.text = textFor(state: synchronizer.latestState.syncStatus)
        progressBar.progress = 0
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        synchronizer.stateStream
            .throttle(for: .seconds(0.2), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: { [weak self] state in self?.synchronizerStateUpdated(state) })
            .store(in: &cancellables)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancellables.forEach { $0.cancel() }
        closureSynchronizer.stop()
    }

    private func synchronizerStateUpdated(_ state: SynchronizerState) {
        self.updateUI()

        switch state.syncStatus {
        case .unprepared:
            break

        case let .syncing(progress):
            enhancingStarted = false

            progressBar.progress = progress
            progressLabel.text = "\(floor(progress * 1000) / 10)%"
            let syncedDate = dateFormatter.string(from: Date(timeIntervalSince1970: state.latestScannedTime))
            let progressText = """
            synced date         \(syncedDate)
            synced block        \(state.latestScannedHeight)
            latest block height \(state.latestBlockHeight)
            """
            progressDataLabel.text = progressText

            if let currentMetric {
                let report = synchronizer.metrics.popBlock(operation: currentMetric)?.last
                metricLabel.text = currentMetricName + report.debugDescription
            }

        case .upToDate:
            accumulateMetrics()
            summaryLabel.text = "enhancement: \(accumulatedMetrics.debugDescription)"
            overallSummary()

        case .error:
            break
        }
    }
    
    func accumulateMetrics() {
        guard let currentMetric else { return }
        if let reports = synchronizer.metrics.popBlock(operation: currentMetric) {
            for report in reports {
                accumulatedMetrics = .accumulate(accumulatedMetrics, current: report)
            }
        }
    }
    
    func overallSummary() {
        let cumulativeSummary = synchronizer.metrics.cumulativeSummary()
        
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
        let syncStatus = synchronizer.latestState.syncStatus
        switch syncStatus {
        case .unprepared, .error:
            do {
                if syncStatus == .unprepared {
                    do {
                        _ = try await synchronizer.prepare(
                            with: DemoAppConfig.defaultSeed,
                            viewingKeys: [AppDelegate.shared.sharedViewingKey],
                            walletBirthday: DemoAppConfig.defaultBirthdayHeight
                        )
                    } catch {
                        loggerProxy.error(error.toZcashError().message)
                        fatalError(error.toZcashError().message)
                    }
                }

                synchronizer.metrics.enableMetrics()
                try await synchronizer.start()
                updateUI()
            } catch {
                loggerProxy.error("Can't start synchronizer: \(error)")
                updateUI()
            }
        default:
            synchronizer.stop()
            synchronizer.metrics.disableMetrics()
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
        let syncStatus = synchronizer.latestState.syncStatus

        statusLabel.text = textFor(state: syncStatus)
        startPause.setTitle(buttonText(for: syncStatus), for: .normal)
        if case SyncStatus.upToDate = syncStatus {
            startPause.isEnabled = false
        } else {
            startPause.isEnabled = true
        }
    }

    func buttonText(for state: SyncStatus) -> String {
        switch state {
        case .syncing:
            return "Pause"
        case .unprepared:
            return "Start"
        case .upToDate:
            return "Chill!"
        case .error:
            return "Retry"
        }
    }

    func textFor(state: SyncStatus) -> String {
        switch state {
        case .syncing:
            return "Syncing 🤖"
        case .upToDate:
            return "Up to Date 😎"
        case .unprepared:
            return "Unprepared"
        case .error(ZcashError.synchronizerDisconnected):
            return "Disconnected"
        case .error:
            return "error 💔"
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

// MARK: Wipe

extension SyncBlocksViewController {
    @objc func wipe(_ sender: Any?) {
        let alert = UIAlertController(
            title: "Wipe the wallet?",
            message: """
            You are about to clear existing databases. All synced blocks, stored TXs, etc will be removed form this device only. If the sync is in
            progress it may take some time. Please be patient.
            """,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "Drop it like it's FIAT",
                style: UIAlertAction.Style.destructive
            ) { [weak self] _ in
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                appDelegate.wipe() { [weak self] possibleError in
                    if let error = possibleError {
                        self?.wipeFailedAlert(error: error)
                    } else {
                        self?.wipeSuccessfullAlert()
                    }
                }
            }
        )

        alert.addAction(UIAlertAction(title: "No please! Have mercy!", style: UIAlertAction.Style.cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    private func wipeSuccessfullAlert() {
        let alert = UIAlertController(
            title: "Wipe is done!",
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func wipeFailedAlert(error: Error) {
        loggerProxy.error("Wipe error: \(error)")

        let alert = UIAlertController(
            title: "Wipe FAILED!",
            message: """
            Something bad happened and wipe failed. This may happen only when some basic IO disk operations failed. The SDK may end up in \
            inconsistent state. It's suggested to call the wipe again until it succeeds. Sorry.

            \(error)
            """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
