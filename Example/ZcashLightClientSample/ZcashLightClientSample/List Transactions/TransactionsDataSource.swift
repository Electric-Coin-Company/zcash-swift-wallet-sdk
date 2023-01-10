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

    func load() throws {
        switch status {
        case .pending:
            transactions = try synchronizer.pendingTransactions.map { pendingTransaction in
                let defaultFee: Zatoshi = kZcashNetwork.constants.defaultFee(for: pendingTransaction.minedHeight)
                let transaction = pendingTransaction.makeTransactionEntity(defaultFee: defaultFee)
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(pendingTransaction: pendingTransaction, memos: memos)
            }
        case .cleared:
            transactions = try synchronizer.clearedTransactions.map { transaction in
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(transaction: transaction, memos: memos)
            }
        case .received:
            transactions = try synchronizer.receivedTransactions.map { transaction in
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(receivedTransaction: transaction, memos: memos)
            }
        case .sent:
            transactions = try synchronizer.sentTransactions.map { transaction in
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(sendTransaction: transaction, memos: memos)
            }
        case .all:
            transactions = try synchronizer.pendingTransactions.map { pendingTransaction in
                let defaultFee: Zatoshi = kZcashNetwork.constants.defaultFee(for: pendingTransaction.minedHeight)
                let transaction = pendingTransaction.makeTransactionEntity(defaultFee: defaultFee)
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(pendingTransaction: pendingTransaction, memos: memos)
            }
            transactions += try synchronizer.clearedTransactions.map { transaction in
                let memos = try synchronizer.getMemos(for: transaction)
                return TransactionDetailModel(transaction: transaction, memos: memos)
            }
        }
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
