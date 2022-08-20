//
//  GetAddressViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 11/1/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
class GetAddressViewController: UIViewController {
    @IBOutlet weak var unifiedAddressLabel: UILabel!
    @IBOutlet weak var tAddressLabel: UILabel!
    @IBOutlet weak var spendingKeyLabel: UILabel! // THIS SHOULD BE SUPER SECRET!!!!!

    // THIS SHOULD NEVER BE STORED IN MEMORY
    // swiftlint:disable:next implicitly_unwrapped_optional
    var spendingKey: SaplingExtendedSpendingKey!

    override func viewDidLoad() {
        super.viewDidLoad()
        let derivationTool = DerivationTool(networkType: kZcashNetwork.networkType)

        // swiftlint:disable:next force_try force_unwrapping
        self.spendingKey = try! derivationTool.deriveSpendingKeys(seed: DemoAppConfig.seed, numberOfAccounts: 1).first!

        // Do any additional setup after loading the view.
        // swiftlint:disable:next line_length
        unifiedAddressLabel.text = (try? derivationTool.deriveUnifiedAddress(seed: DemoAppConfig.seed, accountIndex: 0))?.stringEncoded ?? "No Addresses found"
        tAddressLabel.text = (try? derivationTool.deriveTransparentAddress(seed: DemoAppConfig.seed))?.stringEncoded ?? "could not derive t-address"
        spendingKeyLabel.text = self.spendingKey.stringEncoded
        unifiedAddressLabel.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(addressTapped(_:))
            )
        )
        unifiedAddressLabel.isUserInteractionEnabled = true
        
        tAddressLabel.isUserInteractionEnabled = true
        tAddressLabel.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(tAddressTapped(_:))
            )
        )
        spendingKeyLabel.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(spendingKeyTapped(_:))
            )
        )
        spendingKeyLabel.isUserInteractionEnabled = true
        loggerProxy.info("Address: \(String(describing: Initializer.shared.getAddress()))")
    }

    @IBAction func spendingKeyTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("copied to clipboard")
        
        UIPasteboard.general.string = self.spendingKey.stringEncoded
        let alert = UIAlertController(
            title: "",
            message: "Spending Key Copied to clipboard",
            preferredStyle: UIAlertController.Style.alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func addressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("copied to clipboard")

        UIPasteboard.general.string = unifiedAddressLabel.text

        let alert = UIAlertController(
            title: "",
            message: "Address Copied to clipboard",
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func tAddressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("copied to clipboard")
        UIPasteboard.general.string = try? DerivationTool(networkType: kZcashNetwork.networkType)
            .deriveTransparentAddress(seed: DemoAppConfig.seed).stringEncoded

        let alert = UIAlertController(
            title: "",
            message: "Address Copied to clipboard",
            preferredStyle: UIAlertController.Style.alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
