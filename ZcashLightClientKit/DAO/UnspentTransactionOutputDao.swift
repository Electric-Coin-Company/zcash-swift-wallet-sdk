//
//  UnspentTransactionOutputDAO.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

struct UTXO: Decodable, Encodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "id_utxo"
        case address
        case prevoutTxId = "prevout_txid"
        case prevoutIndex = "prevout_idx"
        case script
        case valueZat = "value_zat"
        case height
        case spentInTx = "spent_in_tx"
    }
    
    var id: Int?
    var address: String
    var prevoutTxId: Data
    var prevoutIndex: Int
    var script: Data
    var valueZat: Int
    var height: Int
    var spentInTx: Int?
}

extension UTXO: UnspentTransactionOutputEntity {
    var txid: Data {
        get {
            prevoutTxId
        }
        set {
            prevoutTxId = newValue
        }
    }
    
    var index: Int {
        get {
            prevoutIndex
        }
        set {
            prevoutIndex = newValue
        }
    }
}

extension UnspentTransactionOutputEntity {
    /**
        As UTXO, with id and spentIntTx set to __nil__
     */
    func asUTXO() -> UTXO {
        UTXO(id: nil, address: address, prevoutTxId: txid, prevoutIndex: index, script: script, valueZat: valueZat, height: height, spentInTx: nil)
    }
}
import SQLite
class UnspentTransactionOutputSQLDAO: UnspentTransactionOutputRepository {
    
    func store(utxos: [UnspentTransactionOutputEntity]) throws {
        do {
            
        let db = try dbProvider.connection()
        try dbProvider.connection().transaction {
            for utxo in utxos.map({ (u) -> UTXO in
                u as? UTXO ?? u.asUTXO()
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
        static var id = Expression<Int>("id_utxo")
        static var address = Expression<String>("address")
        static var txid = Expression<Blob>("prevout_txid")
        static var index = Expression<Int>("prevout_idx")
        static var script = Expression<Blob>("script")
        static var valueZat = Expression<Int>("value_zat")
        static var height = Expression<Int>("height")
        static var spentInTx = Expression<Int?>("spent_in_tx")
    }
    
    var dbProvider: ConnectionProvider
    
    init (dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func createTableIfNeeded() throws {
        
        let stringStatement = """
                   CREATE TABLE IF NOT EXISTS utxos (
                       id_utxo INTEGER PRIMARY KEY,
                       address TEXT NOT NULL,
                       prevout_txid BLOB NOT NULL,
                       prevout_idx INTEGER NOT NULL,
                       script BLOB NOT NULL,
                       value_zat INTEGER NOT NULL,
                       height INTEGER NOT NULL,
                       spent_in_tx INTEGER,
                       FOREIGN KEY (spent_in_tx) REFERENCES transactions(id_tx),
                       CONSTRAINT tx_outpoint UNIQUE (prevout_txid, prevout_idx)
                   )
                   """
        
        try dbProvider.connection().run(stringStatement)
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
    
    func balance(address: String, latestHeight: BlockHeight) throws -> WalletBalance {
        
        do {
            let verified = try dbProvider.connection().scalar(
                    table.select(TableColumns.valueZat.sum)
                        .filter(TableColumns.address == address)
                        .filter(TableColumns.height <= latestHeight - ZcashSDK.DEFAULT_STALE_TOLERANCE)) ?? 0
            let total = try dbProvider.connection().scalar(
                table.select(TableColumns.valueZat.sum)
                    .filter(TableColumns.address == address)) ?? 0
            
            return TransparentBalance(verified: Int64(verified), total: Int64(total), address: address)
        } catch {
            throw StorageError.operationFailed
        }
    }
}

struct TransparentBalance: WalletBalance {
    var verified: Int64
    var total: Int64
    var address: String
}

class UTXORepositoryBuilder {
    static func build(initializer: Initializer) throws -> UnspentTransactionOutputRepository {
        let dao = UnspentTransactionOutputSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path))
        try dao.createTableIfNeeded()
        return dao
    }
}
