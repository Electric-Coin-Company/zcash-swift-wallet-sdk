//
//  TransactionEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation
import SQLite

public enum ZcashTransaction {
    public struct Overview {
        public let accountId: Int
        public let blockTime: TimeInterval?
        public let expiryHeight: BlockHeight?
        public let fee: Zatoshi?
        public let id: Int
        public let index: Int?
        public var isSentTransaction: Bool { value < Zatoshi(0) }
        public let hasChange: Bool
        public let memoCount: Int
        public let minedHeight: BlockHeight?
        public let raw: Data?
        public let rawID: Data
        public let receivedNoteCount: Int
        public let sentNoteCount: Int
        public let value: Zatoshi
        public let isExpiredUmined: Bool
    }

    public struct Received {
        public let blockTime: TimeInterval
        public let expiryHeight: BlockHeight?
        public let fromAccount: Int
        public let id: Int
        public let index: Int
        public let memoCount: Int
        public let minedHeight: BlockHeight
        public let noteCount: Int
        public let raw: Data?
        public let rawID: Data?
        public let value: Zatoshi
    }

    public struct Sent {
        public let blockTime: TimeInterval?
        public let expiryHeight: BlockHeight?
        public let fromAccount: Int
        public let id: Int
        public let index: Int?
        public let memoCount: Int
        public let minedHeight: BlockHeight?
        public let noteCount: Int
        public let raw: Data?
        public let rawID: Data?
        public let value: Zatoshi
    }

    /// Used when fetching blocks from the lightwalletd
    struct Fetched {
        public let rawID: Data
        public let minedHeight: BlockHeight
        public let raw: Data
    }
}

extension ZcashTransaction.Overview {
    enum Column {
        static let accountId = Expression<Int>("account_id")
        static let id = Expression<Int>("id_tx")
        static let minedHeight = Expression<BlockHeight?>("mined_height")
        static let index = Expression<Int?>("tx_index")
        static let rawID = Expression<Blob>("txid")
        static let expiryHeight = Expression<BlockHeight?>("expiry_height")
        static let raw = Expression<Blob?>("raw")
        static let value = Expression<Int64>("account_balance_delta")
        static let fee = Expression<Int64?>("fee_paid")
        static let hasChange = Expression<Bool>("has_change")
        static let sentNoteCount = Expression<Int>("sent_note_count")
        static let receivedNoteCount = Expression<Int>("received_note_count")
        static let memoCount = Expression<Int>("memo_count")
        static let blockTime = Expression<Int64?>("block_time")
        static let expiredUnmined = Expression<Bool>("expired_unmined")
    }

    init(row: Row) throws {
        self.accountId = try row.get(Column.accountId)
        self.expiryHeight = try row.get(Column.expiryHeight)
        self.id = try row.get(Column.id)
        self.index = try row.get(Column.index)
        self.hasChange = try row.get(Column.hasChange)
        self.memoCount = try row.get(Column.memoCount)
        self.minedHeight = try row.get(Column.minedHeight)
        self.rawID = Data(blob: try row.get(Column.rawID))
        self.receivedNoteCount = try row.get(Column.receivedNoteCount)
        self.sentNoteCount = try row.get(Column.sentNoteCount)
        self.value = Zatoshi(try row.get(Column.value))
        self.isExpiredUmined = try row.get(Column.expiredUnmined)
        if let blockTime = try row.get(Column.blockTime) {
            self.blockTime = TimeInterval(blockTime)
        } else {
            self.blockTime = nil
        }

        if let fee = try row.get(Column.fee) {
            self.fee = Zatoshi(fee)
        } else {
            self.fee = nil
        }

        if let raw = try row.get(Column.raw) {
            self.raw = Data(blob: raw)
        } else {
            self.raw = nil
        }
    }

    func anchor(network: ZcashNetwork) -> BlockHeight? {
        guard let minedHeight = self.minedHeight else { return nil }
        if minedHeight != -1 {
            return max(minedHeight - ZcashSDK.defaultStaleTolerance, network.constants.saplingActivationHeight)
        }

        guard let expiryHeight = self.expiryHeight else { return nil }
        if expiryHeight != -1 {
            return max(expiryHeight - ZcashSDK.expiryOffset - ZcashSDK.defaultStaleTolerance, network.constants.saplingActivationHeight)
        }

        return nil
    }
}

extension ZcashTransaction.Received {
    /// Attempts to create a `ZcashTransaction.Received` from an `Overview`
    /// given that the transaction might not be a "sent" transaction, so it won't have the necessary
    /// data to actually create it as it is currently defined, this initializer is optional
    /// - returns: Optional<Received>. `Some` if the values present suffice to create a received
    /// transaction otherwise `.none`
    init?(overview: ZcashTransaction.Overview) {
        guard
            !overview.isSentTransaction,
            let txBlocktime = overview.blockTime,
            let txIndex = overview.index,
            let txMinedHeight = overview.minedHeight
        else { return nil }

        self.blockTime = txBlocktime
        self.expiryHeight = overview.expiryHeight
        self.fromAccount = overview.accountId
        self.id = overview.id
        self.index = txIndex
        self.memoCount = overview.memoCount
        self.minedHeight = txMinedHeight
        self.noteCount = overview.receivedNoteCount
        self.value = overview.value
        self.raw = overview.raw
        self.rawID = overview.rawID
    }
}

extension ZcashTransaction.Sent {
    init?(overview: ZcashTransaction.Overview) {
        guard overview.isSentTransaction else { return nil }

        self.blockTime = overview.blockTime
        self.expiryHeight = overview.expiryHeight
        self.fromAccount = overview.accountId
        self.id = overview.id
        self.index = overview.index
        self.memoCount = overview.memoCount
        self.minedHeight = overview.minedHeight
        self.noteCount = overview.sentNoteCount
        self.value = overview.value
        self.raw = overview.raw
        self.rawID = overview.rawID
    }
}

/**
Capabilities of an entity that can be uniquely identified by a raw transaction id
*/
public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}
