//
//  UnspentTransactionOutputRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/11/20.
//

import Foundation

protocol UnspentTransactionOutputRepository {
    
    func getAll(address: String?) throws -> [UnspentTransactionOutputEntity]
    
    func store(utxos: [UnspentTransactionOutputEntity]) throws
    
    func clearAll(address: String?) throws
}
