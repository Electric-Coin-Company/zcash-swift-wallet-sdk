//
//  NotesDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/18/19.
//

import Foundation
import SQLite

struct ReceivedNote: ReceivedNoteEntity, Codable {
    enum CodingKeys: String, CodingKey {
        case id = "id_note"
        case diversifier
        case rcm
        case nf
        case isChange = "is_change"
        case transactionId = "id_tx"
        case outputIndex = "output_index"
        case account
        case value
        case memo
        case spent
        case tx
    }
    var id: Int
    var diversifier: Data
    var rcm: Data
    var nf: Data
    var isChange: Bool
    var transactionId: Int
    var outputIndex: Int
    var account: Int
    var value: Int
    var memo: Data?
    var spent: Int?
    var tx: Int
}

class ReceivedNotesSQLDAO: ReceivedNoteRepository {
    let table = Table("received_notes")

    var dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func count() throws -> Int {
        try dbProvider.connection().scalar(table.count)
    }
    
    func receivedNote(byRawTransactionId: Data) throws -> ReceivedNoteEntity? {
        let transactions = Table("transactions")
        let idTx = Expression<Int>("id_tx")
        let transaction = Expression<Int>("tx")
        let txid = Expression<Blob>("txid")
        let joinStatement = table
            .join(
                .inner,
                transactions,
                on: transactions[idTx] == table[transaction]
            )
            .where(transactions[txid] == Blob(bytes: byRawTransactionId.bytes))
            .limit(1)
        
        return try dbProvider.connection()
            .prepare(joinStatement)
            .map { row -> ReceivedNote in
                try row.decode()
            }
            .first
    }
}

struct SentNote: SentNoteEntity, Codable {
    enum CodingKeys: String, CodingKey {
        case id = "id_note"
        case transactionId = "tx"
        case outputPool = "output_pool"
        case outputIndex = "output_index"
        case fromAccount = "from_account"
        case toAddress = "to_address"
        case toAccount = "to_account"
        case value
        case memo
    }
    
    var id: Int
    var transactionId: Int
    var outputPool: Int
    var outputIndex: Int
    var fromAccount: Int
    var toAddress: String
    var toAccount: Int
    var value: Int
    var memo: Data?
}

class SentNotesSQLDAO: SentNotesRepository {
    let table = Table("sent_notes")

    var dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func count() throws -> Int {
        try dbProvider.connection().scalar(table.count)
    }
    
    func sentNote(byRawTransactionId: Data) throws -> SentNoteEntity? {
        let transactions = Table("transactions")
        let idTx = Expression<Int>("id_tx")
        let transaction = Expression<Int>("tx")
        let txid = Expression<Blob>("txid")
        let joinStatement = table
            .join(
                .inner,
                transactions,
                on: transactions[idTx] == table[transaction]
            )
            .where(transactions[txid] == Blob(bytes: byRawTransactionId.bytes))
            .limit(1)

        return try dbProvider.connection()
            .prepare(joinStatement)
            .map { row -> SentNote in
                try row.decode()
            }
            .first
    }
}
