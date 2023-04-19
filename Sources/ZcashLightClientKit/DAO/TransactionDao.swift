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
    private var sentNotesRepository: SentNotesRepository
    private let transactionsView = View("v_transactions")
    private let receivedNotesTable = Table("received_notes")
    private let sentNotesTable = Table("sent_notes")
    private let traceClosure: ((String) -> Void)?
    
    init(dbProvider: ConnectionProvider, traceClosure: ((String) -> Void)? = nil) {
        self.dbProvider = dbProvider
        self.blockDao = BlockSQLDAO(dbProvider: dbProvider)
        self.sentNotesRepository = SentNotesSQLDAO(dbProvider: dbProvider)
        self.traceClosure = traceClosure
    }

    private func connection() throws -> Connection {
        let conn = try dbProvider.connection()
        conn.trace(traceClosure)
        return conn
    }

    func closeDBConnection() {
        dbProvider.close()
    }

    func blockForHeight(_ height: BlockHeight) async throws -> Block? {
        try blockDao.block(at: height)
    }

    func lastScannedHeight() async throws -> BlockHeight {
        try blockDao.latestBlockHeight()
    }

    func lastScannedBlock() async throws -> Block? {
        try blockDao.latestBlock()
    }

    func isInitialized() async throws -> Bool {
        true
    }
    
    func countAll() async throws -> Int {
        do {
            return try connection().scalar(transactions.count)
        } catch {
            throw ZcashError.transactionRepositoryCountAll(error)
        }
    }
    
    func countUnmined() async throws -> Int {
        do {
            return try connection().scalar(transactions.filter(ZcashTransaction.Overview.Column.minedHeight == nil).count)
        } catch {
            throw ZcashError.transactionRepositoryCountUnmined(error)
        }
    }

    func find(id: Int) async throws -> ZcashTransaction.Overview {
        let query = transactionsView
            .filter(ZcashTransaction.Overview.Column.id == id)
            .limit(1)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func find(rawID: Data) async throws -> ZcashTransaction.Overview {
        let query = transactionsView
            .filter(ZcashTransaction.Overview.Column.rawID == Blob(bytes: rawID.bytes))
            .limit(1)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func find(offset: Int, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        let query = transactionsView
            .order((ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc)
            .filterQueryFor(kind: kind)
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        let query = transactionsView
            .order((ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc)
            .filter(
                ZcashTransaction.Overview.Column.minedHeight >= BlockHeight(range.lowerBound) &&
                ZcashTransaction.Overview.Column.minedHeight <= BlockHeight(range.upperBound)
            )
            .filterQueryFor(kind: kind)
            .limit(limit)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func find(from transaction: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        guard
            let transactionIndex = transaction.index,
            let transactionBlockTime = transaction.blockTime
        else { throw ZcashError.transactionRepositoryTransactionMissingRequiredFields }
        
        let query = transactionsView
            .order(
                (ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc
            )
            .filter(
                Int64(transactionBlockTime) > ZcashTransaction.Overview.Column.blockTime
                && transactionIndex > ZcashTransaction.Overview.Column.index
            )
            .filterQueryFor(kind: kind)
            .limit(limit)
        
        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Received] {
        let query = transactionsView
            .filterQueryFor(kind: .received)
            .order(ZcashTransaction.Overview.Column.id.desc,(ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc )
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
            .compactMap { ZcashTransaction.Received(overview: $0) }
    }

    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Sent] {
        let query = transactionsView
            .filterQueryFor(kind: .sent)
            .order((ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc)
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
            .compactMap { ZcashTransaction.Sent(overview: $0) }
    }

    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        if transaction.isSentTransaction {
            return try await findMemos(for: transaction.id, table: sentNotesTable)
        } else {
            return try await findMemos(for: transaction.id, table: receivedNotesTable)
        }
    }

    func findMemos(for receivedTransaction: ZcashTransaction.Received) async throws -> [Memo] {
        return try await findMemos(for: receivedTransaction.id, table: receivedNotesTable)
    }

    func findMemos(for sentTransaction: ZcashTransaction.Sent) async throws -> [Memo] {
        return try await findMemos(for: sentTransaction.id, table: sentNotesTable)
    }

    func getRecipients(for id: Int) async -> [TransactionRecipient] {
        return self.sentNotesRepository.getRecipients(for: id)
    }

    private func findMemos(for transactionID: Int, table: Table) async throws -> [Memo] {
        let query = table
            .filter(NotesTableStructure.transactionID == transactionID)
        
        do {
            let memos = try connection().prepare(query).compactMap { row in
                do {
                    let rawMemo = try row.get(NotesTableStructure.memo)
                    return try Memo(bytes: rawMemo.bytes)
                } catch {
                    return nil
                }
            }
            
            return memos
        } catch {
            throw ZcashError.transactionRepositoryFindMemos(error)
        }
    }

    private func execute<Entity>(_ query: View, createEntity: (Row) throws -> Entity) throws -> Entity {
        let entities: [Entity] = try execute(query, createEntity: createEntity)
        guard let entity = entities.first else { throw ZcashError.transactionRepositoryEntityNotFound }
        return entity
    }

    private func execute<Entity>(_ query: View, createEntity: (Row) throws -> Entity) throws -> [Entity] {
        do {
            let entities = try connection()
                .prepare(query)
                .map(createEntity)
            
            return entities
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.transactionRepositoryQueryExecute(error)
            }
        }
    }
}

private extension View {
    func filterQueryFor(kind: TransactionKind) -> View {
        switch kind {
        case .all:
            return self
        case .sent:
            return filter(ZcashTransaction.Overview.Column.value < 0)
        case .received:
            return filter(ZcashTransaction.Overview.Column.value >= 0)
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
