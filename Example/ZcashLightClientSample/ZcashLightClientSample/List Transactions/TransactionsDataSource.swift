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

class TransactionsDataSource: NSObject {
    enum TransactionType {
        case pending
        case sent
        case received
        case cleared
        case all
    }
    
    static let cellIdentifier = "TransactionCell"
    
    // swiftlint:disable:next implicitly_unwrapped_optional
    var synchronizer: Synchronizer!
    var transactions: [TransactionDetailModel] = []

    private var status: TransactionType

    init(status: TransactionType, synchronizer: Synchronizer) {
        self.status = status
        self.synchronizer = synchronizer
    }

    func load() {
        switch status {
        case .pending:
            transactions = synchronizer.pendingTransactions.map {
                TransactionDetailModel(pendingTransaction: $0)
            }
        case .cleared:
            transactions = synchronizer.clearedTransactions.map {
                TransactionDetailModel(confirmedTransaction: $0)
            }
        case .received:
            transactions = synchronizer.receivedTransactions.map {
                TransactionDetailModel(confirmedTransaction: $0)
            }
        case .sent:
            transactions = synchronizer.sentTransactions.map {
                TransactionDetailModel(confirmedTransaction: $0)
            }
        case .all:
            transactions = (
                synchronizer.pendingTransactions.map { $0.transactionEntity } +
                synchronizer.clearedTransactions.map { $0.transactionEntity }
            )
            .map { TransactionDetailModel(transaction: $0) }
        }
    }
    
    func transactionString(_ transcation: TransactionEntity) -> String {
        transcation.transactionId.toHexStringTxId()
    }
}

// MARK: - UITableViewDataSource

extension TransactionsDataSource: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)

        let transaction = transactions[indexPath.row]
        cell.detailTextLabel?.text = transaction.id ?? "no id"
        cell.textLabel?.text = transaction.created ?? "No date"

        return cell
    }
}
