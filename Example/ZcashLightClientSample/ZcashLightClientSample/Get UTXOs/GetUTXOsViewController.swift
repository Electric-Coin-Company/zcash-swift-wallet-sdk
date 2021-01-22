//
//  GetUTXOsViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/9/20.
//  Copyright © 2020 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
import KRProgressHUD
class GetUTXOsViewController: UIViewController {
    @IBOutlet weak var tAddressField: UITextField!
    @IBOutlet weak var getButton: UIButton!
    @IBOutlet weak var getFromCache: UIButton!
    @IBOutlet weak var shieldFundsButton: UIButton!
    @IBOutlet weak var validAddressLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
        
    }
    
    func updateUI() {
        let valid = Initializer.shared.isValidTransparentAddress(tAddressField.text ?? "")
        
        self.validAddressLabel.text = valid ? "Valid TransparentAddress" : "Invalid Transparent address"
        self.validAddressLabel.textColor = valid ? UIColor.systemGreen : UIColor.systemRed
        
        self.getButton.isEnabled = valid
        self.getFromCache.isEnabled = valid
    }
    
    @IBAction func getButtonTapped(_ sender: Any) {
        guard Initializer.shared.isValidTransparentAddress(tAddressField.text ?? ""),
              let tAddr = tAddressField.text else {
            self.messageLabel.text = "Invalid t-Address"
            return
        }
        KRProgressHUD.showMessage("fetching")
        AppDelegate.shared.sharedSynchronizer.latestUTXOs(address: tAddr) { (result) in
            DispatchQueue.main.async { [weak self] in
                KRProgressHUD.dismiss()
                switch result {
                case .success(let utxos):
                    do {
                        let balance = try AppDelegate.shared.sharedSynchronizer.getUnshieldedBalance(address: tAddr)
                    
                        self?.messageLabel.text  = """
                            found \(utxos.count) UTXOs for address \(tAddr)
                            \(balance)
                        """
                    } catch {
                        self?.messageLabel.text = "Error \(error)"
                    }
                    
                case .failure(let error):
                    self?.messageLabel.text = "Error \(error)"
                }
            }
        }
    }
    
    @IBAction func getFromCacheTapped(_ sender: Any) {
        guard Initializer.shared.isValidTransparentAddress(tAddressField.text ?? ""),
              let tAddr = tAddressField.text else {
            self.messageLabel.text = "Invalid t-Address"
            return
        }
        do {
            let utxos = try AppDelegate.shared.sharedSynchronizer.cachedUTXOs(address: tAddr)
            self.messageLabel.text = "found \(utxos.count) UTXOs for address \(tAddr) on cache"
        } catch {
            self.messageLabel.text = "Error \(error)"
        }
    }

    
    @IBAction func viewTapped(_ recognizer: UITapGestureRecognizer)  {
        self.tAddressField.resignFirstResponder()
    }
    
    @IBAction func shieldFunds(_ sender: Any) {
        do {
            let seed =  DemoAppConfig.seed
            let sk = try DerivationTool.default.deriveSpendingKeys(seed: seed, numberOfAccounts: 1).first!
            
            let tsk = try DerivationTool.default.deriveTransparentPrivateKey(seed: seed)
            KRProgressHUD.showMessage("🛡 Shielding 🛡")
            AppDelegate.shared.sharedSynchronizer.shieldFunds(spendingKey: sk, transparentSecretKey: tsk, memo: "shielding is fun!", from: 0) { (result) in
                DispatchQueue.main.async {
                    KRProgressHUD.dismiss()
                    switch result{
                    case .success(let tx):
                        self.messageLabel.text = "funds shielded \(tx)"
                    case .failure(let error):
                        self.messageLabel.text = "Shielding failed: \(error)"
                    }
                }
            }
        } catch {
            self.messageLabel.text = "Error \(error)"
        }
    }
}

extension GetUTXOsViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        updateUI()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)  {
        updateUI()
    }
    
}


extension UnshieldedBalance {
    var description: String {
        """
        UnshieldedBalance:
            confirmed: \(self.confirmed)
            unconfirmed:\(self.unconfirmed)
        """
    }
}
