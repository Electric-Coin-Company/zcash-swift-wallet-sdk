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

    init(sendTransaction transaction: TransactionNG.Sent) {
        self.id = transaction.rawID.toHexStringTxId()
        self.minedHeight = transaction.minedHeight?.description
        self.expiryHeight = transaction.expiryHeight?.description
        self.created = Date(timeIntervalSince1970: transaction.blocktime).description
        self.zatoshi = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: transaction.value.amount))
        // TODO [#683]: Add API to SDK to fetch memos.
//        if let memoData = confirmedTransaction.memo, let memoString = String(bytes: memoData, encoding: .utf8) {
//            self.memo = memoString
//        }
    }

    init(receivedTransaction transaction: TransactionNG.Received) {
        self.id = transaction.rawID.toHexStringTxId()
        self.minedHeight = transaction.minedHeight?.description
        self.expiryHeight = transaction.expiryHeight?.description
        self.created = Date(timeIntervalSince1970: transaction.blocktime).description
        self.zatoshi = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: transaction.value.amount))
        // TODO [#683]: Add API to SDK to fetch memos.
//        if let memoData = confirmedTransaction.memo, let memoString = String(bytes: memoData, encoding: .utf8) {
//            self.memo = memoString
//        }
    }
    
    init(pendingTransaction: PendingTransactionEntity) {
        self.id = pendingTransaction.rawTransactionId?.toHexStringTxId()
        self.minedHeight = pendingTransaction.minedHeight.description
        self.expiryHeight = pendingTransaction.expiryHeight.description
        self.created = Date(timeIntervalSince1970: pendingTransaction.createTime).description
        self.zatoshi = NumberFormatter.zcashNumberFormatter.string(from: NSNumber(value: pendingTransaction.value.amount))
    }
    
    init(transaction: TransactionNG.Overview) {
        self.id = transaction.rawID.toHexStringTxId()
        self.minedHeight = transaction.minedHeight?.description
        self.expiryHeight = transaction.expiryHeight?.description
        self.created = transaction.blocktime.description
        self.zatoshi = "not available in this entity"
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
