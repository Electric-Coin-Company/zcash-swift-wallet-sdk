//
//  TransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/15/19.
//

import Foundation
import SQLite

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
        try dbProvider.connection().scalar(transactions.filter(TransactionNG.Overview.Column.minedHeight == nil).count)
    }
}

// MARK: - Queries

extension TransactionSQLDAO {
    func find(id: Int) throws -> TransactionNG.Overview {
        let query = transactionsView
            .filter(TransactionNG.Overview.Column.id == id)
            .limit(1)

        return try execute(query) { try TransactionNG.Overview(row: $0) }
    }

    func find(rawID: Data) throws -> TransactionNG.Overview {
        let query = transactionsView
            .filter(TransactionNG.Overview.Column.rawID == Blob(bytes: rawID.bytes))
            .limit(1)

        return try execute(query) { try TransactionNG.Overview(row: $0) }
    }

    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview] {
        let query = transactionsView
            .order(TransactionNG.Overview.Column.minedHeight.asc, TransactionNG.Overview.Column.id.asc)
            .filterQueryFor(kind: kind)
            .limit(limit, offset: offset)

        return try execute(query) { try TransactionNG.Overview(row: $0) }
    }

    func find(in range: BlockRange, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview] {
        let query = transactionsView
            .order(TransactionNG.Overview.Column.minedHeight.asc, TransactionNG.Overview.Column.id.asc)
            .filter(
                TransactionNG.Overview.Column.minedHeight >= BlockHeight(range.start.height) &&
                TransactionNG.Overview.Column.minedHeight <= BlockHeight(range.end.height)
            )
            .filterQueryFor(kind: kind)
            .limit(limit)

        return try execute(query) { try TransactionNG.Overview(row: $0) }
    }

    func find(from transaction: TransactionNG.Overview, limit: Int, kind: TransactionKind) throws -> [TransactionNG.Overview] {
        let query = transactionsView
            .order(TransactionNG.Overview.Column.minedHeight.asc, TransactionNG.Overview.Column.id.asc)
            .filter(Int64(transaction.blocktime) > TransactionNG.Overview.Column.blockTime && transaction.index > TransactionNG.Overview.Column.index)
            .filterQueryFor(kind: kind)
            .limit(limit)

        return try execute(query) { try TransactionNG.Overview(row: $0) }
    }

    func findReceived(offset: Int, limit: Int) throws -> [TransactionNG.Received] {
        let query = receivedTransactionsView
            .order(TransactionNG.Received.Column.minedHeight.asc, TransactionNG.Received.Column.id.asc)
            .limit(limit, offset: offset)

        return try execute(query) { try TransactionNG.Received(row: $0) }
    }

    func findSent(offset: Int, limit: Int) throws -> [TransactionNG.Sent] {
        let query = sentTransactionsView
            .order(TransactionNG.Sent.Column.minedHeight.asc, TransactionNG.Sent.Column.id.asc)
            .limit(limit, offset: offset)

        return try execute(query) { try TransactionNG.Sent(row: $0) }
    }

    func findSent(from transaction: TransactionNG.Sent, limit: Int) throws -> [TransactionNG.Sent] {
        let query = sentTransactionsView
            .order(TransactionNG.Sent.Column.minedHeight.asc, TransactionNG.Sent.Column.id.asc)
            .filter(Int64(transaction.blocktime) > TransactionNG.Sent.Column.blockTime && transaction.index > TransactionNG.Sent.Column.index)
            .limit(limit)

        return try execute(query) { try TransactionNG.Sent(row: $0) }
    }

    func findSent(in range: BlockRange, limit: Int) throws -> [TransactionNG.Sent] {
        let query = sentTransactionsView
            .order(TransactionNG.Sent.Column.minedHeight.asc, TransactionNG.Sent.Column.id.asc)
            .filter(
                TransactionNG.Sent.Column.minedHeight >= BlockHeight(range.start.height) &&
                TransactionNG.Sent.Column.minedHeight <= BlockHeight(range.end.height)
            )
            .limit(limit)

        return try execute(query) { try TransactionNG.Sent(row: $0) }
    }

    func findSent(rawID: Data) throws -> TransactionNG.Sent {
        let query = sentTransactionsView
            .order(TransactionNG.Sent.Column.minedHeight.asc, TransactionNG.Sent.Column.id.asc)
            .filter(TransactionNG.Sent.Column.rawID == Blob(bytes: rawID.bytes)).limit(1)

        return try execute(query) { try TransactionNG.Sent(row: $0) }
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
            return filter(TransactionNG.Overview.Column.value < 0)
        case .received:
            return filter(TransactionNG.Overview.Column.value >= 0)
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
