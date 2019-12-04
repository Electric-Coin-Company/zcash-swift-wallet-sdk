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
        // Do any additional setup after loading the view.
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearDatabases(_:)))
    }

    @objc func clearDatabases(_ sender: Any?) {
        let alert = UIAlertController(title: "Clear Databases?", message: "You are about to clear existing databases. You will lose all synced blocks, stored TXs, etc", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Drop it like it's FIAT", style: UIAlertAction.Style.destructive) { _ in 
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
            
            appDelegate.clearDatabases()
            
        })
        
        alert.addAction(UIAlertAction(title: "No please! Have mercy!", style: UIAlertAction.Style.cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
            
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let destination = segue.destination as? TransactionsTableViewController {
            
            if let id = segue.identifier, id == "Pending" {
                destination.datasource = TransactionsDataSource(status: .pending, synchronizer: AppDelegate.shared.sharedSynchronizer)
            } 
        }
        super.prepare(for: segue, sender: sender)
        
        
    }
}

