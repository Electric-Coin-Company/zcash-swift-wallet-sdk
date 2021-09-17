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
        let balance = try! AppDelegate.shared.sharedSynchronizer.getTransparentBalance(accountIndex: 0)
        
        self.totalBalanceLabel.text = String(balance.total.asHumanReadableZecBalance())
        self.verifiedBalanceLabel.text = String(balance.verified.asHumanReadableZecBalance())
    }
    
    @IBAction func shieldFunds(_ sender: Any) {
        do {
            let seed = DemoAppConfig.seed
            let derivationTool = DerivationTool(networkType: kZcashNetwork.networkType)
            // swiftlint:disable:next force_unwrapping
            let spendingKey = try derivationTool.deriveSpendingKeys(seed: seed, numberOfAccounts: 1).first!
            let transparentSecretKey = try derivationTool.deriveTransparentPrivateKey(seed: seed)

            KRProgressHUD.showMessage("🛡 Shielding 🛡")

            AppDelegate.shared.sharedSynchronizer.shieldFunds(
                spendingKey: spendingKey,
                transparentSecretKey: transparentSecretKey,
                memo: "shielding is fun!",
                from: 0,
                resultBlock: { result in
                    DispatchQueue.main.async {
                        KRProgressHUD.dismiss()
                        switch result {
                        case .success(let transaction):
                            self.messageLabel.text = "funds shielded \(transaction)"
                        case .failure(let error):
                            self.messageLabel.text = "Shielding failed: \(error)"
                        }
                    }
                }
            )
        } catch {
            self.messageLabel.text = "Error \(error)"
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
