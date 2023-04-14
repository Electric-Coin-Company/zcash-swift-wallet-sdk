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

    /// Throws `notesDAOReceivedCount` if sqlite query fetching count fails.
    func count() throws -> Int {
        do {
            return try dbProvider.connection().scalar(table.count)
        } catch {
            throw ZcashError.notesDAOReceivedCount(error)
        }
    }

    /// - Throws:
    ///     - `notesDAOReceivedCantDecode` if fetched note data from the db can't be decoded to the `ReceivedNote` object.
    ///     - `notesDAOReceivedNote` if sqlite query fetching note data fails.
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

        do {
            return try dbProvider.connection()
                .prepare(joinStatement)
                .map { row -> ReceivedNote in
                    do {
                        return try row.decode()
                    } catch {
                        throw ZcashError.notesDAOReceivedCantDecode(error)
                    }
                }
                .first
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.notesDAOReceivedNote(error)
            }
        }
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
    var toAddress: String?
    var toAccount: Int?
    var value: Int
    var memo: Data?
}

class SentNotesSQLDAO: SentNotesRepository {
    let table = Table("sent_notes")

    var dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }

    /// - Throws: `notesDAOSentCount` if sqlite query fetching count fails.
    func count() throws -> Int {
        do {
            return try dbProvider.connection().scalar(table.count)
        } catch {
            throw ZcashError.notesDAOSentCount(error)
        }
    }

    /// - Throws:
    ///     - `notesDAOSentCantDecode` if fetched note data from the db can't be decoded to the `SentNote` object.
    ///     - `notesDAOSentNote` if sqlite query fetching note data fails.
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

        do {
            return try dbProvider.connection()
                .prepare(joinStatement)
                .map { row -> SentNote in
                    do {
                        return try row.decode()
                    } catch {
                        throw ZcashError.notesDAOSentCantDecode(error)
                    }
                }
                .first
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.notesDAOSentNote(error)
            }
        }
    }

    func getRecipients(for id: Int) -> [TransactionRecipient] {
        guard let result = try? dbProvider.connection().prepare(
            table.where(id == table[Expression<Int>("tx")])
        ) else { return [] }

        guard let rows = try? result.map({ row -> SentNote in
            try row.decode()
        }) else { return [] }

        return rows.compactMap { sentNote -> TransactionRecipient? in
            if sentNote.toAccount == nil {
                guard
                    let toAddress = sentNote.toAddress,
                    let recipient = Recipient.forEncodedAddress(encoded: toAddress)
                else { return nil }

                return TransactionRecipient.address(recipient.0)
            } else {
                guard let toAccount = sentNote.toAccount else {
                    return nil
                }

                return TransactionRecipient.internalAccount(UInt32(toAccount))
            }
        }
    }
}
