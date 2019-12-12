//
//  TransactionsDataSource.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/4/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import UIKit
import ZcashLightClientKit
class TransactionsDataSource: NSObject, UITableViewDataSource {
    
    enum Status {
        case pending
        case sent
        case received
        case cleared
    }
    static let cellIdentifier = "TransactionCell"
    
    private var status: Status
    var synchronizer: Synchronizer!
    var transactions = [TransactionEntity]()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        
        let tx = transactions[indexPath.row]
        cell.detailTextLabel?.text = transactionString(tx)
        cell.textLabel?.text = tx.created ?? "No date"
        
        return cell
    }
    
    
    init(status: Status, synchronizer: Synchronizer) {
        self.status = status
        self.synchronizer = synchronizer
    }
    
    func load() {
        switch status {
        case .pending:
            transactions = synchronizer.pendingTransactions.map { $0.transactionEntity }
        case .cleared:
            transactions = synchronizer.clearedTransactions.map { $0.transactionEntity }
        case .received:
            transactions = synchronizer.receivedTransactions.map { $0.transactionEntity }
        case .sent:
            transactions = synchronizer.sentTransactions.map { $0.transactionEntity }
        }        
    }
    
    func transactionString(_ tx: TransactionEntity) -> String {
        String(bytes: tx.transactionId, encoding: .utf8) ?? "No Transaction ID"
    }
}

