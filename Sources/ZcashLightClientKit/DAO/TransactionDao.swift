//
//  TransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/15/19.
//

import Foundation
import SQLite

struct Transaction: TransactionEntity {
    enum CodingKeys: String, CodingKey {
        case id = "id_tx"
        case transactionId = "txid"
        case created
        case transactionIndex = "tx_index"
        case expiryHeight = "expiry_height"
        case minedHeight = "block"
        case raw
        case fee
    }
    
    var id: Int?
    var transactionId: Data
    var created: String?
    var transactionIndex: Int?
    var expiryHeight: BlockHeight?
    var minedHeight: BlockHeight?
    var raw: Data?
    var fee: Zatoshi?
}

extension Transaction: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
        self.transactionId = try container.decode(Data.self, forKey: .transactionId)
        self.created = try container.decodeIfPresent(String.self, forKey: .created)
        self.transactionIndex = try container.decodeIfPresent(Int.self, forKey: .transactionIndex)
        self.expiryHeight = try container.decodeIfPresent(BlockHeight.self, forKey: .expiryHeight)
        self.minedHeight = try container.decodeIfPresent(BlockHeight.self, forKey: .minedHeight)
        self.raw = try container.decodeIfPresent(Data.self, forKey: .raw)
        
        if let fee = try container.decodeIfPresent(Int64.self, forKey: .fee) {
            self.fee = Zatoshi(fee)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.id, forKey: .id)
        try container.encode(self.transactionId, forKey: .transactionId)
        try container.encodeIfPresent(self.created, forKey: .created)
        try container.encodeIfPresent(self.transactionIndex, forKey: .transactionIndex)
        try container.encodeIfPresent(self.expiryHeight, forKey: .expiryHeight)
        try container.encodeIfPresent(self.minedHeight, forKey: .minedHeight)
        try container.encodeIfPresent(self.raw, forKey: .raw)
        try container.encodeIfPresent(self.fee?.amount, forKey: .fee)
    }
}

struct ConfirmedTransaction: ConfirmedTransactionEntity {
    var toAddress: String?
    var expiryHeight: BlockHeight?
    var minedHeight: Int
    var noteId: Int
    var blockTimeInSeconds: TimeInterval
    var transactionIndex: Int
    var raw: Data?
    var id: Int?
    var value: Zatoshi
    var memo: Data?
    var rawTransactionId: Data?
    var fee: Zatoshi?
}

class TransactionSQLDAO: TransactionRepository {
    enum TableStructure {
        static var id = Expression<Int>(Transaction.CodingKeys.id.rawValue)
        static var transactionId = Expression<Blob>(Transaction.CodingKeys.transactionId.rawValue)
        static var created = Expression<String?>(Transaction.CodingKeys.created.rawValue)
        static var txIndex = Expression<Int?>(Transaction.CodingKeys.transactionIndex.rawValue)
        static var expiryHeight = Expression<Int?>(Transaction.CodingKeys.expiryHeight.rawValue)
        static var minedHeight = Expression<Int?>(Transaction.CodingKeys.minedHeight.rawValue)
        static var raw = Expression<Blob?>(Transaction.CodingKeys.raw.rawValue)
        static var fee = Expression<Zatoshi?>(Transaction.CodingKeys.fee.rawValue)
    }

    var dbProvider: ConnectionProvider
    var transactions = Table("transactions")
    private var blockDao: BlockSQLDAO
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
        self.blockDao = BlockSQLDAO(dbProvider: dbProvider)
    }

    func blockForHeight(_ height: BlockHeight) throws -> Block? {
        try blockDao.block(at: height)
    }

    func lastScannedHeight() throws -> BlockHeight {
        try blockDao.latestBlockHeight()
    }

    func isInitialized() throws -> Bool {
        true
    }

    func findEncodedTransactionBy(txId: Int) -> EncodedTransaction? {
        // try dbProvider
        return nil
    }
    
    func countAll() throws -> Int {
        try dbProvider.connection().scalar(transactions.count)
    }
    
    func countUnmined() throws -> Int {
        try dbProvider.connection().scalar(transactions.filter(TableStructure.minedHeight == nil).count)
    }
    
    func findBy(id: Int) throws -> TransactionEntity? {
        let query = transactions.filter(TableStructure.id == id).limit(1)
        let sequence = try dbProvider.connection().prepare(query)
        let entity: Transaction? = try sequence.map({ try $0.decode() }).first
        return entity
    }
    
    func findBy(rawId: Data) throws -> TransactionEntity? {
        let query = transactions.filter(TableStructure.transactionId == Blob(bytes: rawId.bytes)).limit(1)
        let entity: Transaction? = try dbProvider.connection().prepare(query).map({ try $0.decode() }).first
        return entity
    }
}

// MARK: - Queries

extension TransactionSQLDAO {
    func findAllSentTransactions(offset: Int = 0, limit: Int = Int.max) throws -> [ConfirmedTransactionEntity]? {
        try dbProvider.connection()
            .run(
                """
                    SELECT
                        transactions.id_tx          AS id,
                        transactions.block          AS minedHeight,
                        transactions.tx_index       AS transactionIndex,
                        transactions.txid           AS rawTransactionId,
                        transactions.expiry_height  AS expiryHeight,
                        transactions.raw            AS raw,
                        sent_notes.to_address       AS toAddress,
                        sent_notes.value            AS value,
                        sent_notes.memo             AS memo,
                        sent_notes.id_note          AS noteId,
                        blocks.time                 AS blockTimeInSeconds,
                        transactions.fee            AS fee
                    FROM    transactions
                        INNER JOIN sent_notes
                            ON transactions.id_tx = sent_notes.tx
                        LEFT JOIN blocks
                            ON transactions.block = blocks.height
                    WHERE  transactions.raw IS NOT NULL
                        AND minedheight > 0

                    ORDER  BY block IS NOT NULL, height DESC, time DESC, txid DESC
                    LIMIT  \(limit) OFFSET \(offset)
                """
            )
            .map { bindings -> ConfirmedTransactionEntity in
                guard let transaction = TransactionBuilder.createConfirmedTransaction(from: bindings) else {
                    throw TransactionRepositoryError.malformedTransaction
                }
                return transaction
            }
    }

    func findAllReceivedTransactions(offset: Int = 0, limit: Int = Int.max) throws -> [ConfirmedTransactionEntity]? {
        try dbProvider.connection()
            .run(
                """
                SELECT
                    transactions.id_tx     AS id,
                    transactions.block     AS minedHeight,
                    transactions.tx_index  AS transactionIndex,
                    transactions.txid      AS rawTransactionId,
                    transactions.raw       AS raw,
                    received_notes.value   AS value,
                    received_notes.memo    AS memo,
                    received_notes.id_note AS noteId,
                    blocks.time            AS blockTimeInSeconds,
                    transactions.fee       AS fee

                FROM    transactions
                    LEFT JOIN received_notes
                        ON transactions.id_tx = received_notes.tx
                    LEFT JOIN blocks
                        ON transactions.block = blocks.height
                WHERE   received_notes.is_change != 1
                ORDER   BY minedheight DESC, blocktimeinseconds DESC, id DESC
                LIMIT   \(limit) OFFSET \(offset)
                """
            )
            .map { bindings -> ConfirmedTransactionEntity in
                guard let transaction = TransactionBuilder.createReceivedTransaction(from: bindings) else {
                    throw TransactionRepositoryError.malformedTransaction
                }
                return transaction
            }
    }

    func findAll(offset: Int = 0, limit: Int = Int.max) throws -> [ConfirmedTransactionEntity]? {
        try dbProvider.connection()
            .run(
                """
                SELECT
                    transactions.id_tx          AS id,
                    transactions.block          AS minedHeight,
                    transactions.tx_index       AS transactionIndex,
                    transactions.txid           AS rawTransactionId,
                    transactions.expiry_height  AS expiryHeight,
                    transactions.raw            AS raw,
                    sent_notes.to_address       AS toAddress,
                        CASE
                            WHEN sent_notes.value IS NOT NULL THEN sent_notes.value
                            ELSE received_notes.value
                    end                          AS value,
                        CASE
                            WHEN sent_notes.memo IS NOT NULL THEN sent_notes.memo
                            ELSE received_notes.memo
                    end                          AS memo,
                        CASE
                            WHEN sent_notes.id_note IS NOT NULL THEN sent_notes.id_note
                            ELSE received_notes.id_note
                    end                          AS noteId,
                    blocks.time                  AS blockTimeInSeconds,
                    transactions.fee             AS fee
                FROM  transactions
                    LEFT JOIN received_notes
                        ON transactions.id_tx = received_notes.tx
                    LEFT JOIN sent_notes
                        ON transactions.id_tx = sent_notes.tx
                    LEFT JOIN blocks
                        ON transactions.block = blocks.height
                WHERE (sent_notes.to_address IS NULL AND received_notes.is_change != 1)
                OR sent_notes.to_address IS NOT NULL
                ORDER  BY ( minedheight IS NOT NULL ),
                    minedheight DESC,
                    blocktimeinseconds DESC,
                    id DESC
                LIMIT  \(limit) OFFSET \(offset)
                """
            )
            .compactMap { TransactionBuilder.createConfirmedTransaction(from: $0) }
    }

    func findAll(from transaction: ConfirmedTransactionEntity?, limit: Int) throws -> [ConfirmedTransactionEntity]? {
        guard let fromTransaction = transaction else {
            return try findAll(offset: 0, limit: limit)
        }

        return try dbProvider.connection()
            .run(
                """
                SELECT transactions.id_tx        AS id,
                    transactions.block           AS minedHeight,
                    transactions.tx_index        AS transactionIndex,
                    transactions.txid            AS rawTransactionId,
                    transactions.expiry_height   AS expiryHeight,
                    transactions.raw             AS raw,
                    sent_notes.to_address        AS toAddress,
                    CASE
                        WHEN sent_notes.value IS NOT NULL THEN sent_notes.value
                        ELSE received_notes.value
                    end                          AS value,
                    CASE
                        WHEN sent_notes.memo IS NOT NULL THEN sent_notes.memo
                        ELSE received_notes.memo
                    end                          AS memo,
                    CASE
                        WHEN sent_notes.id_note IS NOT NULL THEN sent_notes.id_note
                        ELSE received_notes.id_note
                    end                          AS noteId,
                    blocks.time                  AS blockTimeInSeconds,
                    transactions.fee             AS fee
                FROM    transactions
                    LEFT JOIN received_notes
                        ON transactions.id_tx = received_notes.tx
                    LEFT JOIN sent_notes
                        ON transactions.id_tx = sent_notes.tx
                    LEFT JOIN blocks
                        ON transactions.block = blocks.height
                WHERE (\(fromTransaction.blockTimeInSeconds), \(fromTransaction.transactionIndex)) > (blocktimeinseconds, transactionIndex) AND
                    ((sent_notes.to_address IS NULL AND received_notes.is_change != 1)
                    OR sent_notes.to_address IS NOT NULL)
                ORDER  BY ( minedheight IS NOT NULL ),
                    minedheight DESC,
                    blocktimeinseconds DESC,
                    id DESC
                LIMIT  \(limit)
                """
            )
            .compactMap { TransactionBuilder.createConfirmedTransaction(from: $0) }
    }

    func findTransactions(in range: BlockRange, limit: Int = Int.max) throws -> [TransactionEntity]? {
        try dbProvider.connection()
            .run(
                """
                SELECT transactions.id_tx       AS id,
                    transactions.block          AS minedHeight,
                    transactions.tx_index       AS transactionIndex,
                    transactions.txid           AS rawTransactionId,
                    transactions.expiry_height  AS expiryHeight,
                    transactions.raw            AS raw,
                    transactions.fee            AS fee
                FROM   transactions
                WHERE  \(range.start.height) <= minedheight
                AND minedheight <= \(range.end.height)
                ORDER  BY ( minedheight IS NOT NULL ),
                    minedheight ASC,
                    id DESC
                LIMIT  \(limit)
                """
            )
            .compactMap { TransactionBuilder.createTransactionEntity(from: $0) }
    }

    func findConfirmedTransactions(in range: BlockRange, offset: Int = 0, limit: Int = Int.max) throws -> [ConfirmedTransactionEntity]? {
        try dbProvider.connection()
            .run(
                """
                SELECT transactions.id_tx       AS id,
                    transactions.block          AS minedHeight,
                    transactions.tx_index       AS transactionIndex,
                    transactions.txid           AS rawTransactionId,
                    transactions.expiry_height  AS expiryHeight,
                    transactions.raw            AS raw,
                    sent_notes.to_address       AS toAddress,
                    CASE
                        WHEN sent_notes.value IS NOT NULL THEN sent_notes.value
                        ELSE received_notes.value
                    end                         AS value,
                    CASE
                        WHEN sent_notes.memo IS NOT NULL THEN sent_notes.memo
                        ELSE received_notes.memo
                    end                         AS memo,
                    CASE
                        WHEN sent_notes.id_note IS NOT NULL THEN sent_notes.id_note
                        ELSE received_notes.id_note
                    end                         AS noteId,
                    blocks.time                 AS blockTimeInSeconds,
                    transactions.fee            AS fee
                FROM   transactions
                    LEFT JOIN received_notes
                        ON transactions.id_tx = received_notes.tx
                    LEFT JOIN sent_notes
                        ON transactions.id_tx = sent_notes.tx
                    LEFT JOIN blocks
                        ON transactions.block = blocks.height
                WHERE (\(range.start.height) <= minedheight
                    AND minedheight <= \(range.end.height)) AND
                    (sent_notes.to_address IS NULL AND received_notes.is_change != 1)
                    OR sent_notes.to_address IS NOT NULL
                ORDER  BY ( minedheight IS NOT NULL ),
                    minedheight DESC,
                    blocktimeinseconds DESC,
                    id DESC
                LIMIT  \(limit) OFFSET \(offset)
            """
            )
            .compactMap { TransactionBuilder.createConfirmedTransaction(from: $0) }
    }

    func findConfirmedTransactionBy(rawId: Data) throws -> ConfirmedTransactionEntity? {
        try dbProvider.connection()
            .run(
                """
                    SELECT transactions.id_tx       AS id,
                        transactions.block          AS minedHeight,
                        transactions.tx_index       AS transactionIndex,
                        transactions.txid           AS rawTransactionId,
                        transactions.expiry_height  AS expiryHeight,
                        transactions.raw            AS raw,
                        sent_notes.to_address       AS toAddress,
                        CASE
                            WHEN sent_notes.value IS NOT NULL THEN sent_notes.value
                            ELSE received_notes.value
                        end                          AS value,
                        CASE
                            WHEN sent_notes.memo IS NOT NULL THEN sent_notes.memo
                            ELSE received_notes.memo
                        end                          AS memo,
                        CASE
                            WHEN sent_notes.id_note IS NOT NULL THEN sent_notes.id_note
                            ELSE received_notes.id_note
                        end                          AS noteId,
                        blocks.time                  AS blockTimeInSeconds,
                        transactions.fee             AS fee
                    FROM    transactions
                        LEFT JOIN received_notes
                            ON transactions.id_tx = received_notes.tx
                        LEFT JOIN sent_notes
                            ON transactions.id_tx = sent_notes.tx
                        LEFT JOIN blocks
                            ON transactions.block = blocks.height
                    WHERE minedheight >= 0
                        AND rawTransactionId == \(Blob(bytes: rawId.bytes)) AND
                            (sent_notes.to_address IS NULL AND received_notes.is_change != 1)
                        OR sent_notes.to_address IS NOT NULL
                    LIMIT 1
                """
            )
            .compactMap { TransactionBuilder.createConfirmedTransaction(from: $0) }
            .first
    }
}

extension Data {
    init(blob: SQLite.Blob) {
        let bytes = blob.bytes
        self = Data(bytes: bytes, count: bytes.count)
    }
    
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}
