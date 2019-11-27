//
//  PendingTransactionDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation
import SQLite
struct PendingTransaction: PendingTransactionEntity, Decodable, Encodable {
    
    enum CodingKeys: String, CodingKey {
        case toAddress
        case accountIndex
        case minedHeight
        case expiryHeight
        case cancelled
        case encodeAttempts
        case submitAttempts
        case errorMessage
        case errorCode
        case createTime
        case raw
        case id
        case value
        case memo
        case rawTransactionId = "txid"
    }
    
    var toAddress: String
    var accountIndex: Int
    var minedHeight: BlockHeight
    var expiryHeight: BlockHeight
    var cancelled: Int
    var encodeAttempts: Int
    var submitAttempts: Int
    var errorMessage: String?
    var errorCode: Int?
    var createTime: TimeInterval
    var raw: Data?
    var id: Int64
    var value: Int64
    var memo: Data?
    var rawTransactionId: Data?
    
    func isSameTransactionId<T>(other: T) -> Bool where T : RawIdentifiable {
        self.rawTransactionId == other.rawTransactionId
    }
    
    static func from(entity: PendingTransactionEntity) -> PendingTransaction {
        PendingTransaction(toAddress: entity.toAddress,
                           accountIndex: entity.accountIndex,
                           minedHeight: entity.minedHeight,
                           expiryHeight: entity.expiryHeight,
                           cancelled: entity.cancelled,
                           encodeAttempts: entity.encodeAttempts,
                           submitAttempts: entity.submitAttempts,
                           errorMessage: entity.errorMessage,
                           errorCode: entity.errorCode,
                           createTime: entity.createTime,
                           raw: entity.raw,
                           id: entity.id,
                           value: entity.value,
                           memo: entity.memo,
                           rawTransactionId: entity.raw)
    }
}


class PendingTransactionSQLDAO: PendingTransactionRepository {
    
    let table = Table("pending_transactions")
    
    struct TableColumns {
        static var toAddress = Expression<String>("to_address")
        static var accountIndex = Expression<Int64>("account_index")
        static var minedHeight = Expression<Int64?>("mined_height")
        static var expiryHeight = Expression<Int64?>("expiry_height")
        static var cancelled = Expression<Int64?>("cancelled")
        static var encodeAttempts = Expression<Int64?>("encode_attempts")
        static var errorMessage = Expression<String?>("error_message")
        static var submitAttempts = Expression<Int64?>("submit_attempts")
        static var errorCode = Expression<Int64?>("error_code")
        static var createTime = Expression<TimeInterval?>("create_time")
        static var raw = Expression<Blob?>("raw")
        static var id = Expression<Int64>("id")
        static var value = Expression<Int64>("value")
        static var memo = Expression<Blob?>("memo")
        static var rawTransactionId = Expression<Blob?>("txid")
    }
    
    var dbProvider: ConnectionProvider
   
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider        
    }
    
    func createrTableIfNeeded() throws {
        let statement = table.create(ifNotExists: true) { t in
            t.column(TableColumns.id, primaryKey: .autoincrement)
            t.column(TableColumns.toAddress)
            t.column(TableColumns.accountIndex)
            t.column(TableColumns.minedHeight)
            t.column(TableColumns.expiryHeight)
            t.column(TableColumns.cancelled)
            t.column(TableColumns.encodeAttempts, defaultValue: 0)
            t.column(TableColumns.errorMessage)
            t.column(TableColumns.errorCode)
            t.column(TableColumns.submitAttempts, defaultValue: 0)
            t.column(TableColumns.createTime)
            t.column(TableColumns.rawTransactionId)
            t.column(TableColumns.raw)
            t.column(TableColumns.memo)
        }
       
        try dbProvider.connection().run(statement)
    }
    
    func create(_ transaction: PendingTransactionEntity) throws -> Int64 {
        
        let tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        
        return try dbProvider.connection().run(table.insert(tx))
    }
    
    func update(_ transaction: PendingTransactionEntity) throws {
        let tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        try dbProvider.connection().run(table.filter(TableColumns.id == tx.id).update(tx))
    }
    
    func delete(_ transaction: PendingTransactionEntity) throws {
        try dbProvider.connection().run(table.filter(TableColumns.id == transaction.id).delete())
    }
    
    func cancel(_ transaction: PendingTransactionEntity) throws {
        var tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        tx.cancelled = 1
        try dbProvider.connection().run(table.filter(TableColumns.id == tx.id).update(tx))
    }
    
    func find(by id: Int64) throws -> PendingTransactionEntity? {
       guard let row = try dbProvider.connection().pluck(table.filter(TableColumns.id == 1).limit(1)),
        let tx: PendingTransaction = try row.decode() else {
            return nil
        }
        
        return tx
    }
    
    func getAll() throws -> [PendingTransactionEntity] {
        let allTxs: [PendingTransaction] = try dbProvider.connection().prepare(table).map({ row in
            try row.decode()
        })
        return allTxs
    }
    
}
