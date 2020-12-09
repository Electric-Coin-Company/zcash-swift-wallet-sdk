//
//  UnspentTransactionOutputDAO.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

struct UTXO: UnspentTransactionOutputEntity {
    var address: String
    
    var txid: Data
    
    var index: Int32
    
    var script: Data
    
    var valueZat: Int64
    
    var height: UInt64
}
