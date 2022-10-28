//
//  SyncBlocksViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 11/1/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

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

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var processor: CompactBlockProcessor!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        let wallet = Initializer.shared
        // swiftlint:disable:next force_try
        try! wallet.initialize()
        processor = CompactBlockProcessor(initializer: wallet)
        Task { @MainActor in
            statusLabel.text = textFor(state: await processor?.state ?? .stopped)
        }
        progressBar.progress = 0
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processorNotification(_:)),
            name: nil,
            object: processor
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
         
        NotificationCenter.default.removeObserver(self)
        guard let processor = self.processor else { return }
        Task {
            await processor.stop()
        }
    }
    
    @objc func processorNotification(_ notification: Notification) {
        Task { @MainActor in
            guard self.processor != nil else { return }
            
            await self.updateUI()
            
            switch notification.name {
            case let not where not == Notification.Name.blockProcessorUpdated:
                guard let progress = notification.userInfo?[CompactBlockProcessorNotificationKey.progress] as? CompactBlockProgress else { return }
                self.progressBar.progress = progress.progress
                self.progressLabel.text = "\(progress.progress)%"
            default:
                return
            }
        }
    }
    
    @IBAction func startStop() {
        guard let processor = processor else { return }

        Task { @MainActor in
            switch await processor.state {
            case .stopped:
                await startProcessor()
            default:
                await stopProcessor()
            }
        }
    }
    
    func startProcessor() async {
        guard let processor = processor else { return }

        await processor.start()
        await updateUI()
    }
    
    func stopProcessor() async {
        guard let processor = processor else { return }

        await processor.stop()
        await updateUI()
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
        Task { @MainActor in
            await updateUI()
        }
    }
    
    func updateUI() async {
        guard let state = await processor?.state else { return }

        statusLabel.text = textFor(state: state)
        startPause.setTitle(buttonText(for: state), for: .normal)
        if case CompactBlockProcessor.State.synced = state {
            startPause.isEnabled = false
        } else {
            startPause.isEnabled = true
        }
    }
    
    func buttonText(for state: CompactBlockProcessor.State) -> String {
        switch state {
        case .downloading, .scanning, .validating:
            return "Pause"
        case .stopped:
            return "Start"
        case .error:
            return "Retry"
        case .synced:
            return "Chill!"
        case .enhancing:
            return "Enhance"
        case .fetching:
            return "fetch"
        }
    }
    
    func textFor(state: CompactBlockProcessor.State) -> String {
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
        }
    }
}
