//
//  LatestHeightViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 10/31/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit

class LatestHeightViewController: UIViewController {
    
    @IBOutlet weak var blockHeightLabel: UILabel!
    
    var service: LightWalletService = LightWalletGRPCService(host: DemoAppConfig.address, secure: false)
    var model: BlockHeight? {
        didSet {
            if viewIfLoaded != nil {
                setup()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.latestBlockHeight { (result) in
            switch result {
            case .success(let height):
                DispatchQueue.main.async { [weak self] in
                    self?.model = height
                }
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    self?.fail(error)
                }
            }
        }
    }
    
    func setup() {
        guard let model = self.model else {
            return
        }
        blockHeightLabel.text = String(model)
    }
    
    func fail(_ error: LightWalletServiceError) {
        self.blockHeightLabel.text = "Error"
        
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
