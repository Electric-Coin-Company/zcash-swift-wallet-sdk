//
//  UnspentTransactionOutputEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

public protocol UnspentTransactionOutputEntity {
    
    var address: String { get set }
    
    var txid: Data {get set}

    var index: Int32 {get set}

    var script: Data {get set}

    var valueZat: Int64 {get set}

    var height: UInt64 {get set}

}
