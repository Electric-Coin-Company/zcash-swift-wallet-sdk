//
//  ViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 06/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import SwiftUI
import ZcashLightClientKit
// swiftlint:disable force_try implicitly_unwrapped_optional
class MainTableViewController: UITableViewController {
    var switchServerModel: SwitchServerModel!

    var synchronizer: SDKSynchronizer!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearDatabases(_:))
        )

        self.synchronizer = try! SDKSynchronizer(initializer: Initializer.shared)
        try! self.synchronizer.initialize()
        try! self.synchronizer.prepare()
        self.switchServerModel = SwitchServerModel(
            serverAndPort: self.synchronizer.currentEndpoint.serverAndPort,
            serverInfo: "",
            connectionSwitcher: { [weak self] in
                guard let self = self else { return }
                let serverAndPort = self.switchServerModel.serverAndPort.split(separator: ":")

                guard
                    serverAndPort.count == 2,
                    let port = Int(serverAndPort[1]) else {
                    return
                }

                self.synchronizer.switchToEndpoint(
                    LightWalletEndpoint(
                        address: String(serverAndPort[0]),
                        port: port
                    )
                ) { switchResult in
                    DispatchQueue.main.async {
                        switch switchResult {
                        case .success(let info):
                            self.switchServerModel.serverInfo = "\(info)"
                            try! self.synchronizer.start()
                        case .failure(let error):
                            self.switchServerModel.serverInfo = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            },
            currentServer: { [weak self] in
                guard let self = self else { return "No Server Set up." }

                return "\(self.synchronizer.currentEndpoint.host):\(self.synchronizer.currentEndpoint.port)"
            }
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

    @IBSegueAction func showServerSwitching(_ coder: NSCoder) -> UIViewController? {
        let serverSwitchingView = SwitchServerView(model: self.switchServerModel)
            .onAppear {
                try! self.synchronizer.start()
            }
            .onDisappear {
                self.synchronizer.stop()
            }

        return UIHostingController(coder: coder, rootView: serverSwitchingView)
    }
}

extension LightWalletEndpoint {
    var serverAndPort: String {
        "\(self.host):\(self.port)"
    }
}
