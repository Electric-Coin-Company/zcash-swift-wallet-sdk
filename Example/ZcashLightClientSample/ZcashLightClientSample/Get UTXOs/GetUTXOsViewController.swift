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
    @IBOutlet weak var transparentAddressLabel: UILabel!
    @IBOutlet weak var verifiedBalanceLabel: UILabel!
    @IBOutlet weak var totalBalanceLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var shieldFundsButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    
    func updateUI() {
        let synchronizer = SDKSynchronizer.shared

        Task { @MainActor in
            let tAddress = await synchronizer.getTransparentAddress(accountIndex: 0)?.stringEncoded ?? "no t-address found"

            self.transparentAddressLabel.text = tAddress
            
            // swiftlint:disable:next force_try
            let balance = try! await AppDelegate.shared.sharedSynchronizer.getTransparentBalance(accountIndex: 0)
            
            self.totalBalanceLabel.text = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: balance.total.amount))
            self.verifiedBalanceLabel.text = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: balance.verified.amount))
        }
    }
    
    @IBAction func shieldFunds(_ sender: Any) {
        do {
            let derivationTool = DerivationTool(networkType: kZcashNetwork.networkType)

            let usk = try derivationTool.deriveUnifiedSpendingKey(seed: DemoAppConfig.seed, accountIndex: 0)

            KRProgressHUD.showMessage("🛡 Shielding 🛡")

            Task { @MainActor in
                let transaction = try await AppDelegate.shared.sharedSynchronizer.shieldFunds(
                    spendingKey: usk,
                    memo: try Memo(string: "shielding is fun!")
                )
                KRProgressHUD.dismiss()
                self.messageLabel.text = "funds shielded \(transaction)"
            }
        } catch {
            self.messageLabel.text = "Shielding failed \(error)"
        }
    }
}

extension GetUTXOsViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        updateUI()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateUI()
    }
}
