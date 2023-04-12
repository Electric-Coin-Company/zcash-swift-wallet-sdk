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
    enum Transaction {
        case sent(ZcashTransaction.Sent)
        case received(ZcashTransaction.Received)
        case pending(PendingTransactionEntity)
        case cleared(ZcashTransaction.Overview)
    }

    let transaction: Transaction
    var id: Data?
    var minedHeight: BlockHeight?
    var expiryHeight: BlockHeight?
    var created: Date?
    var zatoshi: Zatoshi
    var memo: Memo?
    
    init(sendTransaction transaction: ZcashTransaction.Sent, memos: [Memo]) {
        self.transaction = .sent(transaction)
        self.id = transaction.rawID
        self.minedHeight = transaction.minedHeight
        self.expiryHeight = transaction.expiryHeight

        self.zatoshi = transaction.value
        self.memo = memos.first

        if let blockTime = transaction.blockTime {
            created = Date(timeIntervalSince1970: blockTime)
        } else {
            created = nil
        }
    }

    init(receivedTransaction transaction: ZcashTransaction.Received, memos: [Memo]) {
        self.transaction = .received(transaction)
        self.id = transaction.rawID
        self.minedHeight = transaction.minedHeight
        self.expiryHeight = transaction.expiryHeight
        self.zatoshi = transaction.value
        self.memo = memos.first
        self.created = Date(timeIntervalSince1970: transaction.blockTime)
    }
    
    init(pendingTransaction transaction: PendingTransactionEntity, memos: [Memo]) {
        self.transaction = .pending(transaction)
        self.id = transaction.rawTransactionId
        self.minedHeight = transaction.minedHeight
        self.expiryHeight = transaction.expiryHeight
        self.created = Date(timeIntervalSince1970: transaction.createTime)
        self.zatoshi = transaction.value
        self.memo = memos.first
    }
    
    init(transaction: ZcashTransaction.Overview, memos: [Memo]) {
        self.transaction = .cleared(transaction)
        self.id = transaction.rawID
        self.minedHeight = transaction.minedHeight
        self.expiryHeight = transaction.expiryHeight
        self.zatoshi = transaction.value
        self.memo = memos.first

        if let blockTime = transaction.blockTime {
            created = Date(timeIntervalSince1970: blockTime)
        } else {
            created = nil
        }
    }

    func loadMemos(from synchronizer: Synchronizer) async throws -> [Memo] {
        switch transaction {
        case let .sent(transaction):
            return try await synchronizer.getMemos(for: transaction)
        case let .received(transaction):
            return try await synchronizer.getMemos(for: transaction)
        case .pending:
            return []
        case let .cleared(transaction):
            return try await synchronizer.getMemos(for: transaction)
        }
    }

    func loadMemos(from synchronizer: Synchronizer, completion: @escaping (Result<[Memo], Error>) -> Void) {
        Task {
            do {
                let memos = try await loadMemos(from: synchronizer)
                DispatchQueue.main.async {
                    completion(.success(memos))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
extension TransactionDetailModel {
    var dateDescription: String {
        self.created?.formatted(date: .abbreviated, time: .shortened) ?? "No date"
    }

    var amountDescription: String {
        self.zatoshi.amount.description
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
        idLabel.text = model.id?.toHexStringTxId()
        minedHeightLabel.text = model.minedHeight?.description ?? "no height"
        expiryHeightLabel.text = model.expiryHeight?.description ?? "no height"
        createdLabel.text = model.created?.ISO8601Format()
        zatoshiLabel.text = model.zatoshi.amount.description
        memoLabel.text = model.memo?.toString() ?? "No memo"
        loggerProxy.debug("tx id: \(model.id?.toHexStringTxId() ?? "no id!!"))")

        Task {
            do {
                let memos = try await model.loadMemos(from: AppDelegate.shared.sharedSynchronizer)
                DispatchQueue.main.async { [weak self] in
                    self?.didLoad(memos: memos)
                }
            } catch {
                loggerProxy.error("Error when loading memos: \(error)")
            }
        }
    }

    func didLoad(memos: [Memo]) {
        memoLabel.text = memos.first?.toString()
    }
    
    func formatMemo(_ memo: Data?) -> String {
        guard let memo = memo, let string = String(bytes: memo, encoding: .utf8) else { return "No Memo" }
        return string
    }
    
    func heightToString(height: BlockHeight?) -> String {
        guard let height else { return "NULL" }
        return String(height)
    }
}
