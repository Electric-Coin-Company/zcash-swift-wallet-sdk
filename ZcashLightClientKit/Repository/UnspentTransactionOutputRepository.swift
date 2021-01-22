//
//  UnspentTransactionOutputRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/11/20.
//

import Foundation

public protocol UnshieldedBalance {
    var confirmed: Int64 { get set }
    var unconfirmed: Int64 { get set }
}

protocol UnspentTransactionOutputRepository {
    
    func getAll(address: String?) throws -> [UnspentTransactionOutputEntity]
    
    func balance(address: String, latestHeight: BlockHeight) throws -> UnshieldedBalance 
    
    func store(utxos: [UnspentTransactionOutputEntity]) throws
    
    func clearAll(address: String?) throws
}
