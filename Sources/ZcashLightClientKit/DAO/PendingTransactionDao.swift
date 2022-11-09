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
        case toInternalAccount = "to_internal"
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
        case fee
    }
    
    var recipient: PendingTransactionRecipient
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
    var value: Zatoshi
    var memo: Data?
    var rawTransactionId: Data?
    var fee: Zatoshi?
    
    static func from(entity: PendingTransactionEntity) -> PendingTransaction {
        PendingTransaction(
            recipient: entity.recipient,
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
            rawTransactionId: entity.raw,
            fee: entity.fee
        )
    }
    
    init(
        recipient: PendingTransactionRecipient,
        accountIndex: Int,
        minedHeight: BlockHeight,
        expiryHeight: BlockHeight,
        cancelled: Int,
        encodeAttempts: Int,
        submitAttempts: Int,
        errorMessage: String?,
        errorCode: Int?,
        createTime: TimeInterval,
        raw: Data?,
        id: Int?,
        value: Zatoshi,
        memo: Data?,
        rawTransactionId: Data?,
        fee: Zatoshi?
    ) {
        self.recipient = recipient
        self.accountIndex = accountIndex
        self.minedHeight = minedHeight
        self.expiryHeight = expiryHeight
        self.cancelled = cancelled
        self.encodeAttempts = encodeAttempts
        self.submitAttempts = submitAttempts
        self.errorMessage = errorMessage
        self.errorCode = errorCode
        self.createTime = createTime
        self.raw = raw
        self.id = id
        self.value = value
        self.memo = memo
        self.rawTransactionId = rawTransactionId
        self.fee = fee
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let toAddress: String? = try container.decodeIfPresent(String.self, forKey: .toAddress)
        let toInternalAccount: Int? = try container.decodeIfPresent(Int.self, forKey: .toInternalAccount)

        switch (toAddress, toInternalAccount) {
        case let (.some(address), nil):
            guard let recipient = Recipient.forEncodedAddress(encoded: address) else {
                throw StorageError.malformedEntity(fields: ["toAddress"])
            }
            self.recipient = .address(recipient.0)
        case let (nil, .some(accountId)):
            self.recipient = .internalAccount(UInt32(accountId))
        default:
            throw StorageError.malformedEntity(fields: ["toAddress", "toInternalAccount"])
        }
        
        self.accountIndex = try container.decode(Int.self, forKey: .accountIndex)
        self.minedHeight = try container.decode(BlockHeight.self, forKey: .minedHeight)
        self.expiryHeight = try container.decode(BlockHeight.self, forKey: .expiryHeight)
        self.cancelled = try container.decode(Int.self, forKey: .cancelled)
        self.encodeAttempts = try container.decode(Int.self, forKey: .encodeAttempts)
        self.submitAttempts = try container.decode(Int.self, forKey: .submitAttempts)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        self.errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
        self.createTime = try container.decode(TimeInterval.self, forKey: .createTime)
        self.raw = try container.decodeIfPresent(Data.self, forKey: .raw)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
        
        let zatoshiValue = try container.decode(Int64.self, forKey: .value)
        self.value = Zatoshi(zatoshiValue)
        self.memo = try container.decodeIfPresent(Data.self, forKey: .memo)
        self.rawTransactionId = try container.decodeIfPresent(Data.self, forKey: .rawTransactionId)
        if let feeValue = try container.decodeIfPresent(Int64.self, forKey: .fee) {
            self.fee = Zatoshi(feeValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var toAddress: String?
        var accountId: Int?
        switch (self.recipient) {
        case .address(let recipient):
            toAddress = recipient.stringEncoded
        case .internalAccount(let acct):
            accountId = Int(acct)
        }

        try container.encodeIfPresent(toAddress, forKey: .toAddress)
        try container.encodeIfPresent(accountId, forKey: .toInternalAccount)
        try container.encode(self.accountIndex, forKey: .accountIndex)
        try container.encode(self.minedHeight, forKey: .minedHeight)
        try container.encode(self.expiryHeight, forKey: .expiryHeight)
        try container.encode(self.cancelled, forKey: .cancelled)
        try container.encode(self.encodeAttempts, forKey: .encodeAttempts)
        try container.encode(self.submitAttempts, forKey: .submitAttempts)
        try container.encodeIfPresent(self.errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(self.errorCode, forKey: .errorCode)
        try container.encode(self.createTime, forKey: .createTime)
        try container.encodeIfPresent(self.raw, forKey: .raw)
        try container.encodeIfPresent(self.id, forKey: .id)
        try container.encode(self.value.amount, forKey: .value)
        try container.encodeIfPresent(self.memo, forKey: .memo)
        try container.encodeIfPresent(self.rawTransactionId, forKey: .rawTransactionId)
        try container.encodeIfPresent(self.fee?.amount, forKey: .fee)
    }
    
    func isSameTransactionId<T>(other: T) -> Bool where T: RawIdentifiable {
        self.rawTransactionId == other.rawTransactionId
    }
}

extension PendingTransaction {
    init(value: Zatoshi, recipient: PendingTransactionRecipient, memo: MemoBytes?, account index: Int) {
        var memoData: Data?

        if let memo = memo {
            memoData = Data(memo.bytes)
        }

        self = PendingTransaction(
            recipient: recipient,
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
            value: value,
            memo: memoData,
            rawTransactionId: nil,
            fee: nil
        )
    }
}

class PendingTransactionSQLDAO: PendingTransactionRepository {
    enum TableColumns {
        static var toAddress = Expression<String?>("to_address")
        static var toInternalAccount = Expression<Int?>("to_internal")
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
        static var value = Expression<Zatoshi>("value")
        static var memo = Expression<Blob?>("memo")
        static var rawTransactionId = Expression<Blob?>("txid")
        static var fee = Expression<Zatoshi?>("fee")
    }
    
    static let table = Table("pending_transactions")
    
    var dbProvider: ConnectionProvider
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func create(_ transaction: PendingTransactionEntity) throws -> Int {
        let pendingTx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        
        return try Int(dbProvider.connection().run(Self.table.insert(pendingTx)))
    }
    
    func update(_ transaction: PendingTransactionEntity) throws {
        let pendingTx = transaction as? PendingTransaction ?? PendingTransaction.from(entity: transaction)
        guard let id = pendingTx.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }
        
        let updatedRows = try dbProvider.connection().run(Self.table.filter(TableColumns.id == id).update(pendingTx))
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update pending transactions but no rows were updated")
        }
    }
    
    func delete(_ transaction: PendingTransactionEntity) throws {
        guard let id = transaction.id else {
            throw StorageError.malformedEntity(fields: ["id"])
        }
        
        do {
            try dbProvider.connection().run(Self.table.filter(TableColumns.id == id).delete())
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
        
        try dbProvider.connection().run(Self.table.filter(TableColumns.id == txId).update(pendingTx))
    }
    
    func find(by id: Int) throws -> PendingTransactionEntity? {
        guard let row = try dbProvider.connection().pluck(Self.table.filter(TableColumns.id == id).limit(1)) else {
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
        let allTxs: [PendingTransaction] = try dbProvider.connection().prepare(Self.table).map { row in
            try row.decode()
        }
        
        return allTxs
    }
    
    func applyMinedHeight(_ height: BlockHeight, id: Int) throws {
        let transaction = Self.table.filter(TableColumns.id == id)
        
        let updatedRows = try dbProvider.connection()
            .run(transaction.update([TableColumns.minedHeight <- height]))
        
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update a row but none was updated")
        }
    }
}
