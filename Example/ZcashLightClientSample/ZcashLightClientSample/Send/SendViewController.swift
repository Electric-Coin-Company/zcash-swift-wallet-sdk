//
//  SendViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/3/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
class SendViewController: UIViewController {
    
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var maxFunds: UISwitch!
    @IBOutlet weak var sendButton: UIButton!
    
    var wallet: Initializer = Initializer.shared
    
    var synchronizer: Synchronizer!
    override func viewDidLoad() {
        super.viewDidLoad()
        synchronizer = SDKSynchronizer(initializer: wallet)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        setUp()
    }
    
    @objc func viewTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self.view)
        if addressTextField.isFirstResponder && !addressTextField.frame.contains(point) {
            addressTextField.resignFirstResponder()
        } else if amountTextField.isFirstResponder && !amountTextField.frame.contains(point)  {
            amountTextField.resignFirstResponder()
        }
    }
    func setUp() {
        balanceLabel.text = format(balance: wallet.getBalance())
        toggleSendButton()
    }
    
    func format(balance: Int64 = 0) -> String {
        "Zec \(balance.asHumanReadableZecBalance())"
    }
    
    func toggleSendButton() {
        sendButton.isEnabled = isFormValid()
    }
    
    func maxFundsOn() {
        amountTextField.text = String(wallet.getBalance().asHumanReadableZecBalance())
        amountTextField.isEnabled = false
    }
    
    func maxFundsOff() {
        amountTextField.isEnabled = true
    }
    
    func isFormValid() -> Bool {
        isBalanceValid() && isAmountValid() && isRecipientValid()
    }
    
    func isBalanceValid() -> Bool {
        wallet.getBalance() > 0
    }
    
    func isAmountValid() -> Bool {
        guard let value = amountTextField.text,
            let amount = Double(value),
            amount.toZatoshi() <= wallet.getBalance() else {
                return false
        }
        return true
    }
    
    func isRecipientValid() -> Bool {
        (addressTextField.text ?? "").starts(with: "z") // todo: improve this validation
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
            print("WARNING: Form is invalid")
            return
        }
        
        let alert = UIAlertController(title: "About To send funds!", message: "This is an ugly confirmation message. You should come up with something fancier that let's the user be sure about sending funds without disturbing the user experience with an annoying alert like this one", preferredStyle: UIAlertController.Style.alert)
        
        let sendAction = UIAlertAction(title: "Send!", style: UIAlertAction.Style.default) { (_) in
            self.send()
        }
        let cancelAction = UIAlertAction(title: "Go back! I'm not sure about this.", style: UIAlertAction.Style.destructive) { (_) in
            self.cancel()
        }
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func send() {
        guard isFormValid(), let amount = amountTextField.text, let zec = Double(amount)?.toZatoshi(), let recipient = addressTextField.text else {
            print("WARNING: Form is invalid")
            return
        }
        
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let addresses = appDelegate.addresses else {
            print("NO ADDRESSES")
            return
        }
        
        synchronizer.sendToAddress(spendingKey: addresses[0], zatoshi: zec, toAddress: recipient, memo: nil, from: 0) {  [weak self] result in
            switch result {
            case .success(let pendingTransaction):
                print("transaction created: \(pendingTransaction)")
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.fail(error)
                }
            }
        }
    }
    
    func fail(_ error: Error) {
        let alert = UIAlertController(title: "Send failed!", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
        let action = UIAlertAction(title: "OK :(", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    func cancel() {
        
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
