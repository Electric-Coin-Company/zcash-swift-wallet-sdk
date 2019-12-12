//
//  PendingTransactionsTableViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/4/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.dataSource = datasource
        datasource?.load()
        self.tableView.reloadData()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        
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

}
