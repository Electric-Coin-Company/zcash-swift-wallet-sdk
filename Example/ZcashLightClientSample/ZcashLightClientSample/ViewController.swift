//
//  ViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 06/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit

class MainTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearDatabases(_:))
        )
    }
    
    @objc func clearDatabases(_ sender: Any?) {
        let alert = UIAlertController(
            title: "Clear Databases?",
            message: "You are about to clear existing databases. You will lose all synced blocks, stored TXs, etc",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "Drop it like it's FIAT",
                style: UIAlertAction.Style.destructive
            ) { _ in
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                    return
                }

                appDelegate.clearDatabases()
            }
        )

        alert.addAction(UIAlertAction(title: "No please! Have mercy!", style: UIAlertAction.Style.cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? TransactionsTableViewController {
            if let id = segue.identifier, id == "Pending" {
                destination.datasource = TransactionsDataSource(
                    status: .pending,
                    synchronizer: AppDelegate.shared.sharedSynchronizer
                )
                destination.title = "Pending Transactions"
            } else if let id = segue.identifier, id == "Sent" {
                destination.datasource = TransactionsDataSource(
                    status: .sent,
                    synchronizer: AppDelegate.shared.sharedSynchronizer
                )
                destination.title = "Sent Transactions"
            } else if let id = segue.identifier, id == "Received" {
                destination.datasource = TransactionsDataSource(
                    status: .received,
                    synchronizer: AppDelegate.shared.sharedSynchronizer
                )
                destination.title = "Received Transactions"
            } else if let id = segue.identifier, id == "Cleared" {
                destination.datasource = TransactionsDataSource(
                    status: .cleared,
                    synchronizer: AppDelegate.shared.sharedSynchronizer
                )
                destination.title = "Cleared Transactions"
            } else if let id = segue.identifier, id == "All" {
                destination.datasource = TransactionsDataSource(
                    status: .all,
                    synchronizer: AppDelegate.shared.sharedSynchronizer
                )
                destination.title = "All Transactions"
            }
        } else if let destination = segue.destination as? PaginatedTransactionsViewController {
            let paginatedRepo = AppDelegate.shared.sharedSynchronizer.paginatedTransactions()
            destination.paginatedRepository = paginatedRepo
        }
        super.prepare(for: segue, sender: sender)
    }
}
