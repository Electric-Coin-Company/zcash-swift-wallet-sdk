//
//  TransactionDetailViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
class TransactionDetailViewController: UITableViewController {
    
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var minedHeightLabel: UILabel!
    @IBOutlet weak var expiryHeightLabel: UILabel!
    @IBOutlet weak var createdLabel: UILabel!
    
    var model: TransactionEntity!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setup()
    }
    
    func setup() {
        guard model != nil else { return }
        idLabel.text = model.transactionId.toHexStringTxId()
        minedHeightLabel.text = heightToString(height: model.minedHeight)
        expiryHeightLabel.text = heightToString(height: model.expiryHeight)
        createdLabel.text = model.created
        
        print(model.transactionId.toHexStringTxId())
    }
    
    func formatMemo(_ memo: Data?) -> String {
        guard let memo = memo, let string = String(bytes: memo, encoding: .utf8) else { return "No Memo" }
        return string
    }
    
    func heightToString(height: BlockHeight?) -> String {
        guard let height = height else { return "NULL" }
        return String(height)
    }
}
