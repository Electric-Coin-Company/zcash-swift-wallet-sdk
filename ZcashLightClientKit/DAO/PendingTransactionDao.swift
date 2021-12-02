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

    static func from(entity: PendingTransactionEntity) -> PendingTransaction {
        PendingTransaction(
            toAddress: entity.toAddress,
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
            rawTransactionId: entity.raw
        )
    }

    func isSameTransactionId<T>(other: T) -> Bool where T: RawIdentifiable {
        self.rawTransactionId == other.rawTransactionId
    }
}

extension PendingTransaction {
    // TODO: Handle Memo
    init(value: Int, toAddress: String, memo: String?, account index: Int) {
        self = PendingTransaction(
            toAddress: toAddress,
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
            rawTransactionId: nil
        )
    }
}

class PendingTransactionSQLDAO: PendingTransactionRepository {
    enum TableColumns {
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

    let table = Table("pending_transactions")
    
    var dbProvider: ConnectionProvider
   
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func createrTableIfNeeded() throws {
        let statement = table.create(ifNotExists: true) { createdTable in
            createdTable.column(TableColumns.id, primaryKey: .autoincrement)
            createdTable.column(TableColumns.toAddress)
            createdTable.column(TableColumns.accountIndex)
            createdTable.column(TableColumns.minedHeight)
            createdTable.column(TableColumns.expiryHeight)
            createdTable.column(TableColumns.cancelled)
            createdTable.column(TableColumns.encodeAttempts, defaultValue: 0)
            createdTable.column(TableColumns.errorMessage)
            createdTable.column(TableColumns.errorCode)
            createdTable.column(TableColumns.submitAttempts, defaultValue: 0)
            createdTable.column(TableColumns.createTime)
            createdTable.column(TableColumns.rawTransactionId)
            createdTable.column(TableColumns.value)
            createdTable.column(TableColumns.raw)
            createdTable.column(TableColumns.memo)
        }
       
        try dbProvider.connection().run(statement)
    }
    
    func create(_ transaction: PendingTransactionEntity) throws -> Int {
        let pendingTx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        
        return try Int(dbProvider.connection().run(table.insert(pendingTx)))
    }
    
    func update(_ transaction: PendingTransactionEntity) throws {
        let pendingTx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        guard let id = pendingTx.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }

        let updatedRows = try dbProvider.connection().run(table.filter(TableColumns.id == id).update(pendingTx))
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
        var pendingTx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        pendingTx.cancelled = 1
        guard let txId = pendingTx.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }

        try dbProvider.connection().run(table.filter(TableColumns.id == txId).update(pendingTx))
    }
    
    func find(by id: Int) throws -> PendingTransactionEntity? {
        guard let row = try dbProvider.connection().pluck(table.filter(TableColumns.id == id).limit(1)) else {
            return nil
        }

        do {
            let pendingTx: PendingTransaction = try row.decode()
            return pendingTx
        } catch {
            throw StorageError.operationFailed
        }
    }
    
    func getAll() throws -> [PendingTransactionEntity] {
        let allTxs: [PendingTransaction] = try dbProvider.connection().prepare(table).map { row in
            try row.decode()
        }

        return allTxs
    }
    
    func applyMinedHeight(_ height: BlockHeight, id: Int) throws {
        let transaction = table.filter(TableColumns.id == id)
        
        let updatedRows = try dbProvider.connection()
            .run(transaction.update([TableColumns.minedHeight <- height]))
        
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update a row but none was updated")
        }
    }
}
