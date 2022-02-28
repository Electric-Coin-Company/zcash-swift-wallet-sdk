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
        case outputIndex = "output_index"
        case account = "from_account"
        case address
        case value
        case memo
    }
    
    var id: Int
    var transactionId: Int
    var outputIndex: Int
    var account: Int
    var address: String
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
        //        try dbProvider.connection().run("""
        //            SELECT sent_notes.id_note as id,
        //                sent_notes.tx as transactionId,
//                sent_notes.output_index as outputIndex,
//                sent_notes.account as account,
//                sent_notes.address as address,
//                sent_notes.value as value,
//                sent_notes.memo as memo
//            FROM sent_note JOIN transactions
//            WHERE sent_note.tx = transactions.id_tx AND
//                    transactions.txid = \(Blob(bytes: byRawTransactionId.bytes))
//            """).map({ row -> SentNoteEntity in
//                try row.decode()
//            }).first
    }
}
