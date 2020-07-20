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
        case toAddress = "to_address"
        case accountIndex = "account_index"
        case minedHeight = "mined_height"
        case expiryHeight = "expiry_height"
        case cancelled
        case encodeAttempts = "encode_attempts"
        case submitAttempts = "submit_attempts"
        case errorMessage = "error_message"
        case errorCode = "error_code"
        case createTime = "create_time"
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
    var id: Int?
    var value: Int
    var memo: Data?
    var rawTransactionId: Data?
    
    func isSameTransactionId<T>(other: T) -> Bool where T: RawIdentifiable {
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

extension PendingTransaction {
    
    // TODO: Handle Memo
    init(value: Int, toAddress: String, memo: String?, account index: Int) {
        
        self = PendingTransaction(toAddress: toAddress,
                                  accountIndex: index,
                                  minedHeight: -1,
                                  expiryHeight: -1,
                                  cancelled: 0,
                                  encodeAttempts: 0,
                                  submitAttempts: 0,
                                  errorMessage: nil,
                                  errorCode: nil,
                                  createTime: Date().timeIntervalSince1970,
                                  raw: nil,
                                  id: nil,
                                  value: Int(value),
                                  memo: memo?.encodeAsZcashTransactionMemo(),
                                  rawTransactionId: nil)
    }
}

class PendingTransactionSQLDAO: PendingTransactionRepository {

    let table = Table("pending_transactions")
    
    struct TableColumns {
        static var toAddress = Expression<String>("to_address")
        static var accountIndex = Expression<Int>("account_index")
        static var minedHeight = Expression<Int?>("mined_height")
        static var expiryHeight = Expression<Int?>("expiry_height")
        static var cancelled = Expression<Int?>("cancelled")
        static var encodeAttempts = Expression<Int?>("encode_attempts")
        static var errorMessage = Expression<String?>("error_message")
        static var submitAttempts = Expression<Int?>("submit_attempts")
        static var errorCode = Expression<Int?>("error_code")
        static var createTime = Expression<TimeInterval?>("create_time")
        static var raw = Expression<Blob?>("raw")
        static var id = Expression<Int>("id")
        static var value = Expression<Int>("value")
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
            t.column(TableColumns.value)
            t.column(TableColumns.raw)
            t.column(TableColumns.memo)
        }
       
        try dbProvider.connection().run(statement)
    }
    
    func create(_ transaction: PendingTransactionEntity) throws -> Int {
        
        let tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        
        return try Int(dbProvider.connection().run(table.insert(tx)))
    }
    
    func update(_ transaction: PendingTransactionEntity) throws {
        let tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        guard let id = tx.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }
       let updatedRows = try dbProvider.connection().run(table.filter(TableColumns.id == id).update(tx))
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update pending transactions but no rows were updated")
        }
    }
    
    func delete(_ transaction: PendingTransactionEntity) throws {
        guard let id = transaction.id else {
                  throw StorageError.malformedEntity(fields: ["id"])
              }
        do {
            try dbProvider.connection().run(table.filter(TableColumns.id == id).delete())
        } catch {
            throw StorageError.updateFailed
        }
            
    }
    
    func cancel(_ transaction: PendingTransactionEntity) throws {
        
        var tx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        tx.cancelled = 1
        guard let id = tx.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }
        try dbProvider.connection().run(table.filter(TableColumns.id == id).update(tx))
    }
    
    func find(by id: Int) throws -> PendingTransactionEntity? {
        guard let row = try dbProvider.connection().pluck(table.filter(TableColumns.id == id).limit(1)) else {
            return nil
        }
        do {
            let tx: PendingTransaction = try row.decode()
            return tx
        } catch {
            throw StorageError.operationFailed
        }
    }
    
    func getAll() throws -> [PendingTransactionEntity] {
        let allTxs: [PendingTransaction] = try dbProvider.connection().prepare(table).map({ row in
            try row.decode()
        })
        return allTxs
    }
    
    func applyMinedHeight(_ height: BlockHeight, id: Int) throws {
        
        let tx = table.filter(TableColumns.id == id)
        
        let updatedRows = try dbProvider.connection().run(tx.update(
            [TableColumns.minedHeight <- height]
        ))
        if updatedRows == 0  {
            LoggerProxy.error("attempted to update a row but none was updated")
        }
    }
}
