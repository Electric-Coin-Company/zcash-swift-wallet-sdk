//
//  PendingTransactionsTableViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/4/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
class TransactionsTableViewController: UITableViewController {
    
    var datasource: TransactionsDataSource? {
        didSet {
            self.tableView.dataSource = datasource
            datasource?.load()
            if viewIfLoaded != nil {
                self.tableView.reloadData()
            }
        }
    }
    
    var selectedTx: TransactionDetailModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.dataSource = datasource
        datasource?.load()
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }
    
    var selectedRow: Int?
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if shouldPerformSegue(withIdentifier: "TransactionDetail", sender: self) {
            performSegue(withIdentifier: "TransactionDetail", sender: self)
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "TransactionDetail",
            let row = selectedRow,
            let tx = datasource?.transactions[row] {
            selectedTx = tx
            return true
            
        }
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? TransactionDetailViewController, let tx = selectedTx {
            destination.model = tx
            selectedTx = nil
            selectedRow = nil
        }
    }

}
 
