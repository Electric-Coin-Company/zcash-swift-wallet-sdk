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

/**
 Sync blocks view controller leverages Compact Block Processor directly. This provides more detail on block processing if needed.
 We advise to use the SDKSynchronizer first since it provides a lot of functionality out of the box.
 */
class SyncBlocksViewController: UIViewController {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var startPause: UIButton!

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

                try synchronizer.start()
                updateUI()
            } catch {
                loggerProxy.error("Can't start synchronizer: \(error)")
                updateUI()
            }
        default:
            synchronizer.stop()
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
