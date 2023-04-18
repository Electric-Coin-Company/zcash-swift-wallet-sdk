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
        public let blockTime: TimeInterval?
        public let expiryHeight: BlockHeight?
        public let fee: Zatoshi?
        public let id: Int
        public let index: Int?
        public let isWalletInternal: Bool
        public var isSentTransaction: Bool { value < Zatoshi(0) }
        public let hasChange: Bool
        public let memoCount: Int
        public let minedHeight: BlockHeight?
        public let raw: Data?
        public let rawID: Data
        public let receivedNoteCount: Int
        public let sentNoteCount: Int
        public let value: Zatoshi
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
        static let id = Expression<Int>("id_tx")
        static let minedHeight = Expression<BlockHeight?>("mined_height")
        static let index = Expression<Int?>("tx_index")
        static let rawID = Expression<Blob>("txid")
        static let expiryHeight = Expression<BlockHeight?>("expiry_height")
        static let raw = Expression<Blob?>("raw")
        static let value = Expression<Int64>("net_value")
        static let fee = Expression<Int64?>("fee_paid")
        static let isWalletInternal = Expression<Bool>("is_wallet_internal")
        static let hasChange = Expression<Bool>("has_change")
        static let sentNoteCount = Expression<Int>("sent_note_count")
        static let receivedNoteCount = Expression<Int>("received_note_count")
        static let memoCount = Expression<Int>("memo_count")
        static let blockTime = Expression<Int64?>("block_time")
    }

    init(row: Row) throws {
        do {
            self.expiryHeight = try row.get(Column.expiryHeight)
            self.id = try row.get(Column.id)
            self.index = try row.get(Column.index)
            self.isWalletInternal = try row.get(Column.isWalletInternal)
            self.hasChange = try row.get(Column.hasChange)
            self.memoCount = try row.get(Column.memoCount)
            self.minedHeight = try row.get(Column.minedHeight)
            self.rawID = Data(blob: try row.get(Column.rawID))
            self.receivedNoteCount = try row.get(Column.receivedNoteCount)
            self.sentNoteCount = try row.get(Column.sentNoteCount)
            self.value = Zatoshi(try row.get(Column.value))
            
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
        } catch {
            throw ZcashError.zcashTransactionOverviewInit(error)
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
    enum Column {
        static let id = Expression<Int>("id_tx")
        static let minedHeight = Expression<BlockHeight>("mined_height")
        static let index = Expression<Int>("tx_index")
        static let rawID = Expression<Blob?>("txid")
        static let expiryHeight = Expression<BlockHeight?>("expiry_height")
        static let raw = Expression<Blob?>("raw")
        static let fromAccount = Expression<Int>("received_by_account")
        static let value = Expression<Int64>("received_total")
        static let fee = Expression<Int64>("fee_paid")
        static let noteCount = Expression<Int>("received_note_count")
        static let memoCount = Expression<Int>("memo_count")
        static let blockTime = Expression<Int64>("block_time")
    }

    init(row: Row) throws {
        do {
            self.blockTime = TimeInterval(try row.get(Column.blockTime))
            self.expiryHeight = try row.get(Column.expiryHeight)
            self.fromAccount = try row.get(Column.fromAccount)
            self.id = try row.get(Column.id)
            self.index = try row.get(Column.index)
            self.memoCount = try row.get(Column.memoCount)
            self.minedHeight = try row.get(Column.minedHeight)
            self.noteCount = try row.get(Column.noteCount)
            self.value = Zatoshi(try row.get(Column.value))
            
            if let raw = try row.get(Column.raw) {
                self.raw = Data(blob: raw)
            } else {
                self.raw = nil
            }
            
            if let rawID = try row.get(Column.rawID) {
                self.rawID = Data(blob: rawID)
            } else {
                self.rawID = nil
            }
        } catch {
            throw ZcashError.zcashTransactionReceivedInit(error)
        }
    }
}

extension ZcashTransaction.Sent {
    enum Column {
        static let id = Expression<Int>("id_tx")
        static let minedHeight = Expression<BlockHeight?>("mined_height")
        static let index = Expression<Int?>("tx_index")
        static let rawID = Expression<Blob?>("txid")
        static let expiryHeight = Expression<BlockHeight?>("expiry_height")
        static let raw = Expression<Blob?>("raw")
        static let fromAccount = Expression<Int>("sent_from_account")
        static let value = Expression<Int64>("sent_total")
        static let fee = Expression<Int64>("fee_paid")
        static let noteCount = Expression<Int>("sent_note_count")
        static let memoCount = Expression<Int>("memo_count")
        static let blockTime = Expression<Int64?>("block_time")
    }

    init(row: Row) throws {
        do {
            self.blockTime = try row.get(Column.blockTime).map { TimeInterval($0) }
            self.expiryHeight = try row.get(Column.expiryHeight)
            self.fromAccount = try row.get(Column.fromAccount)
            self.id = try row.get(Column.id)
            self.index = try row.get(Column.index)
            self.memoCount = try row.get(Column.memoCount)
            self.minedHeight = try row.get(Column.minedHeight)
            self.noteCount = try row.get(Column.noteCount)
            self.value = Zatoshi(try row.get(Column.value))
            
            if let raw = try row.get(Column.raw) {
                self.raw = Data(blob: raw)
            } else {
                self.raw = nil
            }
            
            if let rawID = try row.get(Column.rawID) {
                self.rawID = Data(blob: rawID)
            } else {
                self.rawID = nil
            }
        } catch {
            throw ZcashError.zcashTransactionSentInit(error)
        }
    }
}

/**
Capabilities of an entity that can be uniquely identified by a raw transaction id
*/
public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}
