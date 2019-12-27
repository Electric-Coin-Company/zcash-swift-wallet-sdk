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
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension Int64 {
    func asHumanReadableZecBalance() -> Double {
        Double(self) / Double(ZcashSDK.ZATOSHI_PER_ZEC)
    }
}

extension Double {
    func toZatoshi() -> Int64 {
        Int64(self * Double(ZcashSDK.ZATOSHI_PER_ZEC))
    }
}
