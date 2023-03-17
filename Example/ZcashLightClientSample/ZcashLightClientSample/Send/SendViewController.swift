//
//  SendViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/3/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
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
    
    var wallet = Initializer.shared

    // swiftlint:disable:next implicitly_unwrapped_optional
    var synchronizer: Synchronizer!

    var cancellables: [AnyCancellable] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        synchronizer = AppDelegate.shared.sharedSynchronizer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        setUp()
        Task { @MainActor in
            // swiftlint:disable:next force_try
            try! synchronizer.prepare(
                with: DemoAppConfig.seed,
                viewingKeys: [AppDelegate.shared.sharedViewingKey],
                walletBirthday: DemoAppConfig.birthdayHeight
            )
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try synchronizer.start(retry: false)
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: synchronizer.latestState.syncStatus)
        } catch {
            self.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: synchronizer.latestState.syncStatus)
            fail(error)
        }
    }
    
    @objc func viewTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self.view)
        if addressTextField.isFirstResponder && !addressTextField.frame.contains(point) {
            addressTextField.resignFirstResponder()
        } else if amountTextField.isFirstResponder && !amountTextField.frame.contains(point) {
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

        synchronizer.stateStream
            .throttle(for: .seconds(0.2), scheduler: DispatchQueue.main, latest: true)
            .sink(
                receiveValue: { [weak self] state in
                    self?.synchronizerStatusLabel.text = SDKSynchronizer.textFor(state: state.syncStatus)
                }
            )
            .store(in: &cancellables)
    }
    
    func format(balance: Zatoshi = Zatoshi()) -> String {
        "Zec \(balance.formattedString ?? "0.0")"
    }
    
    func toggleSendButton() {
        sendButton.isEnabled = isFormValid()
    }
    
    func maxFundsOn() {
        let fee = Zatoshi(10000)
        let max: Zatoshi = wallet.getVerifiedBalance() - fee
        amountTextField.text = format(balance: max)
        amountTextField.isEnabled = false
    }
    
    func maxFundsOff() {
        amountTextField.isEnabled = true
    }
    
    func isFormValid() -> Bool {
        switch synchronizer.latestState.syncStatus {
        case .synced:
            return isBalanceValid() && isAmountValid() && isRecipientValid()
        default:
            return false
        }
    }
    
    func isBalanceValid() -> Bool {
        wallet.getVerifiedBalance() > .zero
    }
    
    func isAmountValid() -> Bool {
        guard
            let value = amountTextField.text,
            let amount = NumberFormatter.zcashNumberFormatter.number(from: value).flatMap({ Zatoshi($0.int64Value) }),
            amount <= wallet.getVerifiedBalance()
        else {
            return false
        }
        
        return true
    }
    
    func isRecipientValid() -> Bool {
        guard let addr = self.addressTextField.text else {
            return false
        }
        return wallet.isValidSaplingAddress(addr) || wallet.isValidTransparentAddress(addr)
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

        let alert = UIAlertController(
            title: "About To send funds!",
            message: """
            This is an ugly confirmation message. You should come up with something fancier that lets the user be sure about sending funds without \
            disturbing the user experience with an annoying alert like this one
            """,
            preferredStyle: UIAlertController.Style.alert
        )

        let sendAction = UIAlertAction(
            title: "Send!",
            style: UIAlertAction.Style.default,
            handler: { _ in
                self.send()
            }
        )

        let cancelAction = UIAlertAction(
            title: "Go back! I'm not sure about this.",
            style: UIAlertAction.Style.destructive,
            handler: { _ in
                self.cancel()
            }
        )

        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func send() {
        guard
            isFormValid(),
            let amount = amountTextField.text,
            let zec = NumberFormatter.zcashNumberFormatter.number(from: amount).flatMap({ Zatoshi($0.int64Value) }),
            let recipient = addressTextField.text
        else {
            loggerProxy.warn("WARNING: Form is invalid")
            return
        }

        guard let spendingKey = try? DerivationTool(
            networkType: kZcashNetwork.networkType
        )
            .deriveUnifiedSpendingKey(
                seed: DemoAppConfig.seed,
                accountIndex: 0
            )
        else {
            loggerProxy.error("NO SPENDING KEY")
            return
        }
        
        KRProgressHUD.show()
        
        Task { @MainActor in
            do {
                let pendingTransaction = try await synchronizer.sendToAddress(
                    spendingKey: spendingKey,
                    zatoshi: zec,
                    // swiftlint:disable:next force_try
                    toAddress: try! Recipient(recipient, network: kZcashNetwork.networkType),
                    // swiftlint:disable:next force_try
                    memo: try! self.memoField.text.asMemo()
                )
                KRProgressHUD.dismiss()
                loggerProxy.info("transaction created: \(pendingTransaction)")
            } catch {
                fail(error)
                loggerProxy.error("SEND FAILED: \(error)")
            }
        }
    }
    
    func fail(_ error: Error) {
        let alert = UIAlertController(
            title: "Send failed!",
            message: "\(error)",
            preferredStyle: UIAlertController.Style.alert
        )

        let action = UIAlertAction(title: "OK :(", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    func cancel() {}
    
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
        case .syncing(let progress):
            return "Syncing \(progress.progressHeight)/\(progress.targetHeight)"

        case .enhancing(let enhanceProgress):
            return "Enhancing tx \(enhanceProgress.enhancedTransactions) of \(enhanceProgress.totalTransactions)"

        case .fetching:
            return "fetching UTXOs"

        case .disconnected:
            return "disconnected 💔"

        case .stopped:
            return "Stopped 🚫"

        case .synced:
            return "Synced 😎"

        case .unprepared:
            return "Unprepared 😅"

        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

extension Optional where Wrapped == String {
    func asMemo() throws -> Memo {
        switch self {
        case .some(let string):
            return try Memo(string: string)
        case .none:
            return .empty
        }
    }
}
