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
        // swiftlint:disable:next force_try
        let tAddress = try! DerivationTool(networkType: kZcashNetwork.networkType)
            .deriveTransparentAddress(seed: DemoAppConfig.seed)

        self.transparentAddressLabel.text = tAddress

        // swiftlint:disable:next force_try
        Task { @MainActor in
            let balance = try! await AppDelegate.shared.sharedSynchronizer.getTransparentBalance(accountIndex: 0)
            
            self.totalBalanceLabel.text = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: balance.total.amount))
            self.verifiedBalanceLabel.text = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: balance.verified.amount))
        }
    }
    
    @IBAction func shieldFunds(_ sender: Any) {
        do {
            let seed = DemoAppConfig.seed
            let derivationTool = DerivationTool(networkType: kZcashNetwork.networkType)
            // swiftlint:disable:next force_unwrapping
            let spendingKey = try derivationTool.deriveSpendingKeys(seed: seed, numberOfAccounts: 1).first!
            let transparentSecretKey = try derivationTool.deriveTransparentPrivateKey(seed: seed)

            KRProgressHUD.showMessage("🛡 Shielding 🛡")

            Task { @MainActor in
                let transaction = try await AppDelegate.shared.sharedSynchronizer.shieldFunds(
                    spendingKey: spendingKey,
                    transparentSecretKey: transparentSecretKey,
                    memo: "shielding is fun!",
                    from: 0)
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
