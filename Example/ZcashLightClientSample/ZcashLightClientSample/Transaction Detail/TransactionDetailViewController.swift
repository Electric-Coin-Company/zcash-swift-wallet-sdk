//
//  TransactionDetailViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit

final class TransactionDetailModel {
    var id: String?
    var minedHeight: String?
    var expiryHeight: String?
    var created: String?
    var zatoshi: String?
    var memo: String?
    
    init() {}

    init(sendTransaction transaction: ZcashTransaction.Sent, memos: [Memo]) {
        self.id = transaction.rawID?.toHexStringTxId()
        self.minedHeight = transaction.minedHeight?.description
        self.expiryHeight = transaction.expiryHeight?.description

        self.zatoshi = transaction.value.decimalString()
        self.memo = memos.first?.toString()

        if let blockTime = transaction.blockTime {
            created = Date(timeIntervalSince1970: blockTime).description
        } else {
            created = nil
        }
    }

    init(receivedTransaction transaction: ZcashTransaction.Received, memos: [Memo]) {
        self.id = transaction.rawID?.toHexStringTxId()
        self.minedHeight = transaction.minedHeight.description
        self.expiryHeight = transaction.expiryHeight?.description
        self.created = Date(timeIntervalSince1970: transaction.blockTime).description
        self.zatoshi = transaction.value.decimalString()
        self.memo = memos.first?.toString()
    }
    
    init(pendingTransaction transaction: PendingTransactionEntity, memos: [Memo]) {
        self.id = transaction.rawTransactionId?.toHexStringTxId()
        self.minedHeight = transaction.minedHeight.description
        self.expiryHeight = transaction.expiryHeight.description
        self.created = Date(timeIntervalSince1970: transaction.createTime).description
        self.zatoshi = transaction.value.decimalString()
        self.memo = memos.first?.toString()
    }
    
    init(transaction: ZcashTransaction.Overview, memos: [Memo]) {
        self.id = transaction.rawID.toHexStringTxId()
        self.minedHeight = transaction.minedHeight?.description
        self.expiryHeight = transaction.expiryHeight?.description
        self.created = transaction.blockTime?.description
        self.zatoshi = transaction.value.decimalString()
        self.memo = memos.first?.toString()
    }
}

// swiftlint:disable implicitly_unwrapped_optional
class TransactionDetailViewController: UITableViewController {
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var minedHeightLabel: UILabel!
    @IBOutlet weak var expiryHeightLabel: UILabel!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var zatoshiLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!

    var model: TransactionDetailModel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setup()
    }
    
    func setup() {
        guard model != nil else { return }
        idLabel.text = model.id
        minedHeightLabel.text = model.minedHeight ?? "no height"
        expiryHeightLabel.text = model.expiryHeight ?? "no height"
        createdLabel.text = model.created
        zatoshiLabel.text = model.zatoshi
        memoLabel.text = model.memo ?? "No memo"
        loggerProxy.debug("tx id: \(model.id ?? "no id!!"))")
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
