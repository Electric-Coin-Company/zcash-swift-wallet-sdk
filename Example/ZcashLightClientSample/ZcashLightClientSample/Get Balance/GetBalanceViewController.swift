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
        self.title = "Account 0 Balance"
        self.balance.text = "\(Initializer.shared.getBalance().asHumanReadableZecBalance()) ZEC"
        self.verified.text = "\(Initializer.shared.getVerifiedBalance().asHumanReadableZecBalance()) ZEC"
    }
}

extension Int64 {
    func asHumanReadableZecBalance() -> Double {
        Double(self) / Double(ZcashSDK.zatoshiPerZEC)
    }
}

extension Double {
    func toZatoshi() -> Int64 {
        Int64(self * Double(ZcashSDK.zatoshiPerZEC))
    }
}
