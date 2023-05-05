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

    let dbProvider: ConnectionProvider
    
    private let blockDao: BlockSQLDAO
    private let transactionsView = View("v_transactions")
    private let txOutputsView = View("v_tx_outputs")
    private let traceClosure: ((String) -> Void)?
    
    init(dbProvider: ConnectionProvider, traceClosure: ((String) -> Void)? = nil) {
        self.dbProvider = dbProvider
        self.blockDao = BlockSQLDAO(dbProvider: dbProvider)
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
            return try connection().scalar(transactionsView.count)
        } catch {
            throw ZcashError.transactionRepositoryCountAll(error)
        }
    }
    
    func countUnmined() async throws -> Int {
        do {
            return try connection().scalar(transactionsView.filter(ZcashTransaction.Overview.Column.minedHeight == nil).count)
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

    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        let query = transactionsView
            .filterQueryFor(kind: .received)
            .order(ZcashTransaction.Overview.Column.id.desc, (ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc)
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        let query = transactionsView
            .filterQueryFor(kind: .sent)
            .order((ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc)
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func findPendingTransactions(latestHeight: BlockHeight, offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        let query = transactionsView
            .filterPendingFrom(latestHeight)
            .order((ZcashTransaction.Overview.Column.minedHeight ?? BlockHeight.max).desc, ZcashTransaction.Overview.Column.id.desc)
            .limit(limit, offset: offset)

        return try execute(query) { try ZcashTransaction.Overview(row: $0) }
    }

    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        do {
            return try await getTransactionOutputs(for: transaction.id)
                .compactMap { $0.memo }
        } catch {
            throw ZcashError.transactionRepositoryFindMemos(error)
        }
    }

    func getTransactionOutputs(for id: Int) async throws -> [ZcashTransaction.Output] {
        let query = self.txOutputsView
            .filter(ZcashTransaction.Output.Column.idTx == id)

        return try execute(query) { try ZcashTransaction.Output(row: $0) }
    }

    func getRecipients(for id: Int) async throws -> [TransactionRecipient] {
        try await getTransactionOutputs(for: id).map { $0.recipient }
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
    func filterPendingFrom(_ latestHeight: BlockHeight) -> View {
        filter(
            // transaction has not expired
            ZcashTransaction.Overview.Column.expiredUnmined == false &&
            // transaction is "sent"
            ZcashTransaction.Overview.Column.value < 0 &&
            // transaction has not been mined yet OR
            // it has been within the latest `defaultStaleTolerance` blocks
            (
                ZcashTransaction.Overview.Column.minedHeight == nil ||
                ZcashTransaction.Overview.Column.minedHeight > (latestHeight - ZcashSDK.defaultStaleTolerance)
            )
        )

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
