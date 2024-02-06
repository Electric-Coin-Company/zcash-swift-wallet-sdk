//
//  UnspentTransactionOutputRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/11/20.
//

import Foundation

protocol UnspentTransactionOutputRepository {
    func initialise() async throws
    func getAll(address: String?) async throws -> [UnspentTransactionOutputEntity]
    func store(utxos: [UnspentTransactionOutputEntity]) async throws
    func clearAll(address: String?) async throws
}
