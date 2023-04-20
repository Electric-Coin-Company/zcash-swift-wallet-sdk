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
    
    let id: Int?
    let address: String
    var prevoutTxId: Data
    var prevoutIndex: Int
    let script: Data
    let valueZat: Int
    let height: Int
    let spentInTx: Int?
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
        UTXO(
            id: nil,
            address: address,
            prevoutTxId: txid,
            prevoutIndex: index,
            script: script,
            valueZat: valueZat,
            height: height,
            spentInTx: nil
        )
    }
}
import SQLite
class UnspentTransactionOutputSQLDAO: UnspentTransactionOutputRepository {
    enum TableColumns {
        static let id = Expression<Int>("id_utxo")
        static let address = Expression<String>("address")
        static let txid = Expression<Blob>("prevout_txid")
        static let index = Expression<Int>("prevout_idx")
        static let script = Expression<Blob>("script")
        static let valueZat = Expression<Int>("value_zat")
        static let height = Expression<Int>("height")
        static let spentInTx = Expression<Int?>("spent_in_tx")
    }

    let table = Table("utxos")

    let dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }

    /// - Throws: `unspentTransactionOutputDAOCreateTable` if creation table fails.
    func initialise() async throws {
        try await createTableIfNeeded()
    }
    
    private func createTableIfNeeded() async throws {
        let stringStatement =
            """
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
        do {
            try dbProvider.connection().run(stringStatement)
        } catch {
            throw ZcashError.unspentTransactionOutputDAOCreateTable(error)
        }
    }

    /// - Throws: `unspentTransactionOutputDAOStore` if sqlite query fails.
    func store(utxos: [UnspentTransactionOutputEntity]) async throws {
        do {
            let db = try dbProvider.connection()
            try dbProvider.connection().transaction {
                for utxo in utxos.map({ $0 as? UTXO ?? $0.asUTXO() }) {
                    try db.run(table.insert(utxo))
                }
            }
        } catch {
            throw ZcashError.unspentTransactionOutputDAOStore(error)
        }
    }

    /// - Throws: `unspentTransactionOutputDAOClearAll` if sqlite query fails.
    func clearAll(address: String?) async throws {
        do {
            if let tAddr = address {
                try dbProvider.connection().run(table.filter(TableColumns.address == tAddr).delete())
            } else {
                try dbProvider.connection().run(table.delete())
            }
        } catch {
            throw ZcashError.unspentTransactionOutputDAOClearAll(error)
        }
    }

    ///  - Throws:
    ///     - `unspentTransactionOutputDAOClearAll` if the data fetched from the DB can't be decoded to `UTXO` object.
    ///     - `unspentTransactionOutputDAOGetAll` if sqlite query fails.
    func getAll(address: String?) async throws -> [UnspentTransactionOutputEntity] {
        do {
            if let tAddress = address {
                let allTxs: [UTXO] = try dbProvider.connection()
                    .prepare(table.filter(TableColumns.address == tAddress))
                    .map { row in
                        do {
                            return try row.decode()
                        } catch {
                            throw ZcashError.unspentTransactionOutputDAOGetAllCantDecode(error)
                        }
                    }
                return allTxs
            } else {
                let allTxs: [UTXO] = try dbProvider.connection()
                    .prepare(table)
                    .map { row in
                        try row.decode()
                    }
                return allTxs
            }
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.unspentTransactionOutputDAOGetAll(error)
            }
        }
    }

    /// - Throws: `unspentTransactionOutputDAOBalance` if sqlite query fails.
    func balance(address: String, latestHeight: BlockHeight) async throws -> WalletBalance {
        do {
            let verified = try dbProvider.connection().scalar(
                table.select(TableColumns.valueZat.sum)
                    .filter(TableColumns.address == address)
                    .filter(TableColumns.height <= latestHeight - ZcashSDK.defaultStaleTolerance)
            ) ?? 0
            let total = try dbProvider.connection().scalar(
                table.select(TableColumns.valueZat.sum)
                    .filter(TableColumns.address == address)
            ) ?? 0
            
            return WalletBalance(
                verified: Zatoshi(Int64(verified)),
                total: Zatoshi(Int64(total))
            )
        } catch {
            throw ZcashError.unspentTransactionOutputDAOBalance(error)
        }
    }
}

struct TransparentBalance {
    var balance: WalletBalance
    var address: String
}

enum UTXORepositoryBuilder {
    static func build(initializer: Initializer) -> UnspentTransactionOutputRepository {
        return UnspentTransactionOutputSQLDAO(dbProvider: SimpleConnectionProvider(path: initializer.dataDbURL.path))
    }
}
