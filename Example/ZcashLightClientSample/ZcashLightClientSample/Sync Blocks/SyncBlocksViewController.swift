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

    private var processor: CompactBlockProcessor?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        let wallet = Initializer.shared
        
        processor = CompactBlockProcessor(initializer: wallet)
        
        statusLabel.text = textFor(state: processor?.state ?? .stopped)
        progressBar.progress = 0
        
        NotificationCenter.default.addObserver(self, selector: #selector(processorNotification(_:)), name: nil, object: processor)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
         
        NotificationCenter.default.removeObserver(self)
        guard let processor = self.processor else { return }
        processor.stop()
    }
    
    @objc func processorNotification(_ notification: Notification) {
        DispatchQueue.main.async {
            guard self.processor != nil else { return }
            
            self.updateUI()
            
            switch notification.name {
            case let not where not == Notification.Name.blockProcessorUpdated:
                guard let progress = notification.userInfo?[CompactBlockProcessorNotificationKey.progress] as? Float else { return }
                self.progressBar.progress = progress
                self.progressLabel.text = "\(progress)%"
            default:
                return
            }
        }
    }
    
    @IBAction func startStop() {
        
        guard let processor = processor else { return }
        switch processor.state {
        case .stopped:
            startProcessor()
        default:
            stopProcessor()
        }
    }
    
    func startProcessor() {
        guard let processor = processor else { return }
        do {
            try processor.start()
            updateUI()
        } catch {
            fail(error: error)
        }
        
    }
    
    func stopProcessor() {
        guard let processor = processor else { return }
        processor.stop(cancelTasks: true)
        updateUI()
    }
    
    func fail(error: Error) {
        let alert = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { (_) in
            self.navigationController?.popViewController(animated: true)
        }))
        
        self.present(alert, animated: true, completion: nil)
        
        updateUI()
    }
    
    func updateUI() {
        
        guard let state = processor?.state else { return }
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
        case .error(_):
            return "Retry"
        case .synced:
            return "Chill!"
        }
    }
    
    func textFor(state: CompactBlockProcessor.State) -> String {
        switch state {
        case .downloading:
            return "Downloading ⛓"
        case .error(_):
            return "error 💔"
        case .scanning:
            return "Scanning Blocks 🤖"
        case .stopped:
            return "Stopped 🚫"
        case .validating:
            return "Validating chain 🕵️‍♀️"
        case .synced:
            return "Synced 😎"
        }
    }
}
