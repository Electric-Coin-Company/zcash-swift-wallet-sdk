//
//  TransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/15/19.
//

import Foundation
import SQLite



struct Transaction: TransactionEntity, Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "id_tx"
        case transactionId = "txid"
        case created
        case transactionIndex = "tx_index"
        case expiryHeight = "expiry_height"
        case minedHeight = "block"
        case raw
    }
    
    var id: Int
    var transactionId: Data
    var created: String?
    var transactionIndex: Int?
    var expiryHeight: BlockHeight?
    var minedHeight: BlockHeight?
    var raw: Data?
}

class TransactionSQLDAO: TransactionRepository {
    
    struct TableStructure {
        static var id = Expression<Int64>(Transaction.CodingKeys.id.rawValue)
        static var transactionId = Expression<Blob>(Transaction.CodingKeys.transactionId.rawValue)
        static var created = Expression<String?>(Transaction.CodingKeys.created.rawValue)
        static var txIndex = Expression<String?>(Transaction.CodingKeys.transactionIndex.rawValue)
        static var expiryHeight = Expression<Int64?>(Transaction.CodingKeys.expiryHeight.rawValue)
        static var minedHeight = Expression<Int64?>(Transaction.CodingKeys.minedHeight.rawValue)
        static var raw = Expression<Blob?>(Transaction.CodingKeys.raw.rawValue)
    }
    
    var dbProvider: ConnectionProvider
    
    var transactions = Table("transactions")
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func countAll() throws -> Int {
        try dbProvider.connection().scalar(transactions.count)
    }
    
    func countUnmined() throws -> Int {
        try dbProvider.connection().scalar(transactions.filter(TableStructure.minedHeight == nil).count)
    }
    
    func findBy(id: Int) throws -> TransactionEntity? {
        let query = transactions.filter(TableStructure.id == Int64(id)).limit(1)
        let entity: Transaction? = try dbProvider.connection().prepare(query).map({ try $0.decode() }).first
        return entity
    }
    
    func findBy(rawId: Data) throws -> TransactionEntity? {
        let query = transactions.filter(TableStructure.transactionId == Blob(bytes: rawId.bytes)).limit(1)
        let entity: Transaction? = try dbProvider.connection().prepare(query).map({ try $0.decode() }).first
        return entity
    }
    
    func findAllSentTransactions(limit: Int) throws -> [ConfirmedTransaction]? {
        nil
    }
    
    func findAllReceivedTransactions(limit: Int) throws -> [ConfirmedTransaction]? {
        nil
    }
    
    func findAll(limit: Int) throws -> [ConfirmedTransaction]? {
        nil
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
    var data : Data{
        return Data(self)
    }
}
