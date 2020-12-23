//
//  UnspentTransactionOutputDAO.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

struct UTXO: UnspentTransactionOutputEntity, Decodable, Encodable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case address
        case txid
        case index
        case script
        case valueZat = "value_zat"
        case height
    }
    
    var id: Int?
    
    var address: String
    
    var txid: Data
    
    var index: Int
    
    var script: Data
    
    var valueZat: Int
    
    var height: Int
    
}

import SQLite
class UnspentTransactionOutputSQLDAO: UnspentTransactionOutputRepository {
    
    func store(utxos: [UnspentTransactionOutputEntity]) throws {
        do {
            
        let db = try dbProvider.connection()
        try dbProvider.connection().transaction {
            for utxo in utxos.map({ (u) -> UTXO in
                u as? UTXO ?? UTXO(id: nil,
                                   address: u.address,
                                   txid: u.txid,
                                   index: Int(u.index),
                                   script: u.script,
                                   valueZat: u.valueZat,
                                   height: u.height)
            }) {
                try db.run(table.insert(utxo))
            }
        }
        } catch {
            throw StorageError.transactionFailed(underlyingError: error)
        }
    }
    
    func clearAll(address: String?) throws {
        
        if let tAddr = address {
            do {
                try dbProvider.connection().run(table.filter(TableColumns.address == tAddr).delete())
            } catch {
                throw StorageError.operationFailed
            }
        } else {
            do {
                try dbProvider.connection().run(table.delete())
            } catch {
                throw StorageError.operationFailed
            }
        }
    }
    
    let table = Table("utxos")
    
    struct TableColumns  {
        static var id = Expression<Int>("id")
        static var address = Expression<String>("address")
        static var txid = Expression<Blob>("txid")
        static var index = Expression<Int>("index")
        static var script = Expression<Blob>("script")
        static var valueZat = Expression<Int>("value_zat")
        static var height = Expression<Int>("height")
    }
    
    var dbProvider: ConnectionProvider
    
    init (dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func createTableIfNeeded() throws {
        let statement = table.create(ifNotExists: true) { t in
            t.column(TableColumns.id, primaryKey: .autoincrement)
            t.column(TableColumns.address)
            t.column(TableColumns.txid)
            t.column(TableColumns.index)
            t.column(TableColumns.script)
            t.column(TableColumns.valueZat)
            t.column(TableColumns.height)
        }
        try dbProvider.connection().run(statement)
    }
    
    func getAll(address: String?) throws -> [UnspentTransactionOutputEntity] {
        if let tAddress = address {
            let allTxs: [UTXO] = try dbProvider.connection().prepare(table.filter(TableColumns.address == tAddress)).map({ row in
                try row.decode()
            })
            return allTxs
        } else {
            let allTxs: [UTXO] = try dbProvider.connection().prepare(table).map({ row in
                try row.decode()
            })
            return allTxs
        }
    }
    
    func balance(address: String) throws -> Int {
        
        guard let sum = try dbProvider.connection().scalar(
                table.select(TableColumns.valueZat.sum)
                    .filter(TableColumns.address == address)
        ) else {
            throw StorageError.operationFailed
        }
        return sum
        
    }
}

class UTXORepositoryBuilder {
    static func build(initializer: Initializer) throws -> UnspentTransactionOutputRepository {
        let dao = UnspentTransactionOutputSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.cacheDbURL.path))
        try dao.createTableIfNeeded()
        return dao
    }
}
