//
//  GetBalanceViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 11/26/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit

class GetBalanceViewController: UIViewController {
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var verified: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let synchronizer = AppDelegate.shared.sharedSynchronizer
        self.title = "Account 0 Balance"

        Task { @MainActor in
            let balance = try? await synchronizer.getAccountBalance()
            let balanceText = (balance?.saplingBalance.total().formattedString) ?? "0.0"
            let verifiedText = (balance?.saplingBalance.spendableValue.formattedString) ?? "0.0"
            let usdZecRate = try await synchronizer.getExchangeRateUSD()
            let usdBalance = (balance?.saplingBalance.total().decimalValue ?? 0).multiplying(by: usdZecRate)
            let usdVerified = (balance?.saplingBalance.spendableValue.decimalValue ?? 0).multiplying(by: usdZecRate)
            self.balance.text = "\(balanceText) ZEC\n\(usdBalance) USD\n\n(\(usdZecRate) USD/ZEC)"
            self.verified.text = "\(verifiedText) ZEC\n\(usdVerified) USD"
        }
    }
}

extension Zatoshi {
    var formattedString: String? {
        decimalString(formatter: NumberFormatter.zcashNumberFormatter)
    }
}
