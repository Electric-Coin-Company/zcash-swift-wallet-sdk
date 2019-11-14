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
    @IBOutlet weak var addressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        addressLabel.text =  legibleAddresses() ?? "No Addresses found"
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func legibleAddresses() -> String? {
        Initializer.shared.getAddress()
    }
}

extension SeedProvider {
    func seed() -> [UInt8] {
        Array(DemoAppConfig.address.utf8)
    }
}
