//
//  SendViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/3/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
import KRProgressHUD
class SendViewController: UIViewController {
    
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var verifiedBalanceLabel: UILabel!
    @IBOutlet weak var maxFunds: UISwitch!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var synchronizerStatusLabel: UILabel!
    @IBOutlet weak var memoField: UITextView!
    @IBOutlet weak var charactersLeftLabel: UILabel!
    
    let characterLimit: Int = 512
    
    var wallet: Initializer = Initializer.shared
    
    var synchronizer: Synchronizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        synchronizer = AppDelegate.shared.sharedSynchronizer
        try! synchronizer.prepare()
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        setUp()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try synchronizer.start(retry: false)
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: synchronizer.status)
        } catch {
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: synchronizer.status)
            fail(error)
        }
    }
    
    @objc func viewTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self.view)
        if addressTextField.isFirstResponder && !addressTextField.frame.contains(point) {
            addressTextField.resignFirstResponder()
        } else if amountTextField.isFirstResponder && !amountTextField.frame.contains(point)  {
            amountTextField.resignFirstResponder()
        } else if memoField.isFirstResponder &&
            !memoField.frame.contains(point) {
            memoField.resignFirstResponder()
        }
    }
    
    func setUp() {
        balanceLabel.text = format(balance: wallet.getBalance())
        verifiedBalanceLabel.text = format(balance: wallet.getVerifiedBalance())
        toggleSendButton()
        memoField.text = ""
        memoField.layer.borderColor = UIColor.gray.cgColor
        memoField.layer.borderWidth = 1
        memoField.layer.cornerRadius = 5
        charactersLeftLabel.text = textForCharacterCount(0)
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(synchronizerStarted(_:)), name: Notification.Name.synchronizerStarted, object: synchronizer)
        center.addObserver(self, selector: #selector(synchronizerSynced(_:)), name: Notification.Name.synchronizerSynced, object: synchronizer)
        center.addObserver(self, selector: #selector(synchronizerStopped(_:)), name: Notification.Name.synchronizerStopped, object: synchronizer)
        center.addObserver(self, selector: #selector(synchronizerUpdated(_:)), name: Notification.Name.synchronizerProgressUpdated, object: synchronizer)
    }
    
    
    func format(balance: Int64 = 0) -> String {
        "Zec \(balance.asHumanReadableZecBalance())"
    }
    
    func toggleSendButton() {
        sendButton.isEnabled = isFormValid()
    }
    
    func maxFundsOn() {
        let fee: Int64 = 10000
        let max = wallet.getVerifiedBalance() - fee
        amountTextField.text = String(max.asHumanReadableZecBalance())
        amountTextField.isEnabled = false
    }
    
    func maxFundsOff() {
        amountTextField.isEnabled = true
    }
    
    func isFormValid() -> Bool {
        switch synchronizer.status {
        case .synced:
            return isBalanceValid() && isAmountValid() && isRecipientValid()
        default:
            return false
        } 
    }
    
    func isBalanceValid() -> Bool {
        wallet.getVerifiedBalance() > 0
    }
    
    func isAmountValid() -> Bool {
        guard let value = amountTextField.text,
            let amount = Double(value),
            amount.toZatoshi() <= wallet.getVerifiedBalance() else {
                return false
        }
        return true
    }
    
    func isRecipientValid() -> Bool {
        guard let addr = self.addressTextField.text else {
            return false
        }
        return wallet.isValidShieldedAddress(addr) || wallet.isValidTransparentAddress(addr)
    }
    
    @IBAction func maxFundsValueChanged(_ sender: Any) {
        if maxFunds.isOn {
            maxFundsOn()
        } else {
            maxFundsOff()
        }
    }
    
    @IBAction func send(_ sender: Any) {
        guard isFormValid() else {
            loggerProxy.warn("WARNING: Form is invalid")
            return
        }
        
        let alert = UIAlertController(title: "About To send funds!",
                                      message: "This is an ugly confirmation message. You should come up with something fancier that lets the user be sure about sending funds without disturbing the user experience with an annoying alert like this one",
                                      preferredStyle: UIAlertController.Style.alert)
        
        let sendAction = UIAlertAction(title: "Send!", style: UIAlertAction.Style.default) { (_) in
            self.send()
        }
        let cancelAction = UIAlertAction(title: "Go back! I'm not sure about this.",
                                         style: UIAlertAction.Style.destructive) { (_) in
                                            self.cancel()
        }
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    func send() {
        guard isFormValid(), let amount = amountTextField.text, let zec = Double(amount)?.toZatoshi(), let recipient = addressTextField.text else {
            loggerProxy.warn("WARNING: Form is invalid")
            return
        }
        
        
        guard let address = SampleStorage.shared.privateKey else {
            loggerProxy.error("NO ADDRESS")
            return
        }
        
        KRProgressHUD.show()
        
        synchronizer.sendToAddress(spendingKey: address, zatoshi: zec, toAddress: recipient, memo: self.memoField.text.count > 0 ? self.memoField.text : nil, from: 0) {  [weak self] result in
            
            DispatchQueue.main.async {
                KRProgressHUD.dismiss()
            }
            switch result {
            case .success(let pendingTransaction):
                loggerProxy.info("transaction created: \(pendingTransaction)")
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.fail(error)
                    loggerProxy.error("SEND FAILED: \(error)")
                }
            }
        }
    }
    
    func fail(_ error: Error) {
        let alert = UIAlertController(title: "Send failed!", message: "\(error)", preferredStyle: UIAlertController.Style.alert)
        let action = UIAlertAction(title: "OK :(", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    func cancel() {
        
    }
    
    // MARK: synchronizer notifications
    @objc func synchronizerUpdated(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: self.synchronizer.status)
        }
    }
    
    @objc func synchronizerStarted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: self.synchronizer.status)
        }
    }
    
    @objc func synchronizerStopped(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: self.synchronizer.status)
        }
        
    }
    
    @objc func synchronizerSynced(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: self.synchronizer.status)
        }
    }
    
    func textForCharacterCount(_ count: Int) -> String {
        "\(count) of \(characterLimit) bytes left"
    }
}


extension SendViewController: UITextFieldDelegate {
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == amountTextField {
            return !maxFunds.isOn
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        toggleSendButton()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == amountTextField {
            addressTextField.becomeFirstResponder()
            return false
        }
        textField.resignFirstResponder()
        return true
    }
}

extension SendViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let userPressedDelete = text.isEmpty && range.length > 0
        return textView.text.utf8.count < characterLimit || userPressedDelete
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.charactersLeftLabel.text = textForCharacterCount(textView.text.utf8.count)
    }
}

extension SDKSynchronizer {
    static func textFor(state: SyncStatus) -> String {
        switch state {
        case .downloading(let progress):
            return "Downloading \(progress.progressHeight)/\(progress.targetHeight)"
        case .enhancing(let enhanceProgress):
            return "Enhancing tx \(enhanceProgress.enhancedTransactions) of \(enhanceProgress.totalTransactions)"
        case .fetching:
            return "fetching UTXOs"
        case .scanning(let scanProgress):
            return "Scanning: \(scanProgress.progressHeight)/\(scanProgress.targetHeight)"
        case .disconnected:
            return "disconnected 💔"
        case .stopped:
            return "Stopped 🚫"
        case .synced:
            return "Synced 😎"
        case .unprepared:
            return "Unprepared 😅"
        case .validating:
            return "Validating"
        case .error(let e):
            return "Error: \(e.localizedDescription)"
        }
    }
}
