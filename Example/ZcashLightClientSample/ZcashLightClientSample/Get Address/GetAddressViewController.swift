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
    @IBOutlet weak var zAddressLabel: UILabel!
    @IBOutlet weak var tAddressLabel: UILabel!
    @IBOutlet weak var spendingKeyLabel: UILabel! // THIS SHOULD BE SUPER SECRET!!!!!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        zAddressLabel.text = (try? DerivationTool.default.deriveShieldedAddress(seed: DemoAppConfig.seed, accountIndex: 0)) ?? "No Addresses found"
        tAddressLabel.text = (try? DerivationTool.default.deriveTransparentAddress(seed: DemoAppConfig.seed)) ?? "could not derive t-address"
        spendingKeyLabel.text = SampleStorage.shared.privateKey ?? "No Spending Key found"
        zAddressLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addressTapped(_:))))
        zAddressLabel.isUserInteractionEnabled = true
        
        tAddressLabel.isUserInteractionEnabled = true
        tAddressLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tAddressTapped(_:))))
        spendingKeyLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spendingKeyTapped(_:))))
        spendingKeyLabel.isUserInteractionEnabled = true
        loggerProxy.info("Address: \(String(describing: Initializer.shared.getAddress()))")
        // NOTE: NEVER LOG YOUR PRIVATE KEYS IN REAL LIFE
        print("Spending Key: \(SampleStorage.shared.privateKey ?? "No Spending Key found")")
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func spendingKeyTapped(_ gesture: UIGestureRecognizer) {
        guard let key =  SampleStorage.shared.privateKey else {
            loggerProxy.warn("nothing to copy")
            return
        }
        
        loggerProxy.event("copied to clipboard")
        
        UIPasteboard.general.string = key
        let alert = UIAlertController(title: "", message: "Spending Key Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func addressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("copied to clipboard")
        UIPasteboard.general.string = try? DerivationTool.default.deriveShieldedAddress(seed: DemoAppConfig.seed, accountIndex: 0)
        let alert = UIAlertController(title: "", message: "Address Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func tAddressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("copied to clipboard")
        UIPasteboard.general.string = try? DerivationTool.default.deriveTransparentAddress(seed: DemoAppConfig.seed)
        let alert = UIAlertController(title: "", message: "Address Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
