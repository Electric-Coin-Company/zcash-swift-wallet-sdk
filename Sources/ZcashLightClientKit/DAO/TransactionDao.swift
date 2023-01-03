//
//  TransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/15/19.
//

import Foundation
import SQLite

class TransactionSQLDAO: TransactionRepository {
    var dbProvider: ConnectionProvider
    var transactions = Table("transactions")
    private var blockDao: BlockSQLDAO

    fileprivate let transactionsView = View("v_transactions")
    fileprivate let receivedTransactionsView = View("v_tx_received")
    fileprivate let sentTransactionsView = View("v_tx_sent")
    
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
        let query = transactionsView
            .order(Transaction.Overview.Column.minedHeight.asc, Transaction.Overview.Column.id.asc)
            .filter(Int64(transaction.blocktime) > Transaction.Overview.Column.blockTime && transaction.index > Transaction.Overview.Column.index)
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

    func findSent(from transaction: Transaction.Sent, limit: Int) throws -> [Transaction.Sent] {
        let query = sentTransactionsView
            .order(Transaction.Sent.Column.minedHeight.asc, Transaction.Sent.Column.id.asc)
            .filter(Int64(transaction.blocktime) > Transaction.Sent.Column.blockTime && transaction.index > Transaction.Sent.Column.index)
            .limit(limit)

        return try execute(query) { try Transaction.Sent(row: $0) }
    }

    func findSent(in range: BlockRange, limit: Int) throws -> [Transaction.Sent] {
        let query = sentTransactionsView
            .order(Transaction.Sent.Column.minedHeight.asc, Transaction.Sent.Column.id.asc)
            .filter(
                Transaction.Sent.Column.minedHeight >= BlockHeight(range.start.height) &&
                Transaction.Sent.Column.minedHeight <= BlockHeight(range.end.height)
            )
            .limit(limit)

        return try execute(query) { try Transaction.Sent(row: $0) }
    }

    func findSent(rawID: Data) throws -> Transaction.Sent {
        let query = sentTransactionsView
            .order(Transaction.Sent.Column.minedHeight.asc, Transaction.Sent.Column.id.asc)
            .filter(Transaction.Sent.Column.rawID == Blob(bytes: rawID.bytes)).limit(1)

        return try execute(query) { try Transaction.Sent(row: $0) }
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
