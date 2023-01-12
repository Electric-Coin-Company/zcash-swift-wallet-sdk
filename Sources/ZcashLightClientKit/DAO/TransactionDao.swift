//
//  TransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/15/19.
//

import Foundation
import SQLite

class TransactionSQLDAO: TransactionRepository {
    enum NotesTableStructure {
        static let transactionID = Expression<Int>("tx")
        static let memo = Expression<Blob>("memo")
    }

    var dbProvider: ConnectionProvider
    var transactions = Table("transactions")
    private var blockDao: BlockSQLDAO

    fileprivate let transactionsView = View("v_transactions")
    fileprivate let receivedTransactionsView = View("v_tx_received")
    fileprivate let sentTransactionsView = View("v_tx_sent")
    fileprivate let receivedNotesTable = Table("received_notes")
    fileprivate let sentNotesTable = Table("sent_notes")
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
        self.blockDao = BlockSQLDAO(dbProvider: dbProvider)
    }

    func closeDBConnection() {
        dbProvider.close()
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
    
    func countAll() throws -> Int {
        try dbProvider.connection().scalar(transactions.count)
    }
    
    func countUnmined() throws -> Int {
        try dbProvider.connection().scalar(transactions.filter(Transaction.Overview.Column.minedHeight == nil).count)
    }
}

// MARK: - Queries

extension TransactionSQLDAO {
    func find(id: Int) throws -> Transaction.Overview {
        let query = transactionsView
            .filter(Transaction.Overview.Column.id == id)
            .limit(1)

        return try execute(query) { try Transaction.Overview(row: $0) }
    }

    func find(rawID: Data) throws -> Transaction.Overview {
        let query = transactionsView
            .filter(Transaction.Overview.Column.rawID == Blob(bytes: rawID.bytes))
            .limit(1)

        return try execute(query) { try Transaction.Overview(row: $0) }
    }

    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview] {
        let query = transactionsView
            .order(Transaction.Overview.Column.minedHeight.asc, Transaction.Overview.Column.id.asc)
            .filterQueryFor(kind: kind)
            .limit(limit, offset: offset)

        return try execute(query) { try Transaction.Overview(row: $0) }
    }

    func find(in range: BlockRange, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview] {
        let query = transactionsView
            .order(Transaction.Overview.Column.minedHeight.asc, Transaction.Overview.Column.id.asc)
            .filter(
                Transaction.Overview.Column.minedHeight >= BlockHeight(range.start.height) &&
                Transaction.Overview.Column.minedHeight <= BlockHeight(range.end.height)
            )
            .filterQueryFor(kind: kind)
            .limit(limit)

        return try execute(query) { try Transaction.Overview(row: $0) }
    }

    func find(from transaction: Transaction.Overview, limit: Int, kind: TransactionKind) throws -> [Transaction.Overview] {
        guard
            let transactionIndex = transaction.index,
            let transactionBlockTime = transaction.blockTime
        else { throw TransactionRepositoryError.transactionMissingRequiredFields }

        let query = transactionsView
            .order(Transaction.Overview.Column.minedHeight.asc, Transaction.Overview.Column.id.asc)
            .filter(Int64(transactionBlockTime) > Transaction.Overview.Column.blockTime && transactionIndex > Transaction.Overview.Column.index)
            .filterQueryFor(kind: kind)
            .limit(limit)

        return try execute(query) { try Transaction.Overview(row: $0) }
    }

    func findReceived(offset: Int, limit: Int) throws -> [Transaction.Received] {
        let query = receivedTransactionsView
            .order(Transaction.Received.Column.minedHeight.asc, Transaction.Received.Column.id.asc)
            .limit(limit, offset: offset)

        return try execute(query) { try Transaction.Received(row: $0) }
    }

    func findSent(offset: Int, limit: Int) throws -> [Transaction.Sent] {
        let query = sentTransactionsView
            .order(Transaction.Sent.Column.minedHeight.asc, Transaction.Sent.Column.id.asc)
            .limit(limit, offset: offset)

        return try execute(query) { try Transaction.Sent(row: $0) }
    }

    func findMemos(for transaction: Transaction.Overview) throws -> [Memo] {
        guard let transactionID = transaction.id else { throw TransactionRepositoryError.transactionMissingRequiredFields }
        return try findMemos(for: transactionID, table: receivedNotesTable)
    }

    func findMemos(for receivedTransaction: Transaction.Received) throws -> [Memo] {
        guard let transactionID = receivedTransaction.id else { throw TransactionRepositoryError.transactionMissingRequiredFields }
        return try findMemos(for: transactionID, table: receivedNotesTable)
    }

    func findMemos(for sentTransaction: Transaction.Sent) throws -> [Memo] {
        guard let transactionID = sentTransaction.id else { throw TransactionRepositoryError.transactionMissingRequiredFields }
        return try findMemos(for: transactionID, table: sentNotesTable)
    }

    private func findMemos(for transactionID: Int, table: Table) throws -> [Memo] {
        let query = table
            .filter(NotesTableStructure.transactionID == transactionID)
        
        let memos = try dbProvider.connection().prepare(query).compactMap { row in
            do {
                let rawMemo = try row.get(NotesTableStructure.memo)
                return try Memo(bytes: rawMemo.bytes)
            } catch {
                return nil
            }
        }

        return memos
    }

    private func execute<Entity>(_ query: View, createEntity: (Row) throws -> Entity) throws -> Entity {
        let entities: [Entity] = try execute(query, createEntity: createEntity)
        guard let entity = entities.first else { throw TransactionRepositoryError.notFound }
        return entity
    }

    private func execute<Entity>(_ query: View, createEntity: (Row) throws -> Entity) throws -> [Entity] {
        let entities = try dbProvider
            .connection()
            .prepare(query)
            .map(createEntity)

        return entities
    }
}

private extension View {
    func filterQueryFor(kind: TransactionKind) -> View {
        switch kind {
        case .all:
            return self
        case .sent:
            return filter(Transaction.Overview.Column.value < 0)
        case .received:
            return filter(Transaction.Overview.Column.value >= 0)
        }
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
