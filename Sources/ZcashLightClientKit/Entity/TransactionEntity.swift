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
        /// Represents the transaction state based on current height of the chain,
        /// mined height and expiry height of a transaction.
        public enum State {
            /// transaction has a `minedHeight` that's greater or equal than
            /// `ZcashSDK.defaultStaleTolerance` confirmations.
            case confirmed
            /// transaction has no `minedHeight` but current known height is less than
            /// `expiryHeight`.
            case pending
            /// transaction has no
            case expired

            init(
                currentHeight: BlockHeight,
                minedHeight: BlockHeight?,
                expiredUnmined: Bool?
            ) {
                guard let expiredUnmined, !expiredUnmined else {
                    self = .expired
                    return
                }

                if let minedHeight, (currentHeight - minedHeight) >= ZcashSDK.defaultStaleTolerance {
                    self = .confirmed
                } else if let minedHeight, (currentHeight - minedHeight) < ZcashSDK.defaultStaleTolerance {
                    self = .pending
                } else if minedHeight == nil {
                    self = .pending
                } else {
                    self = .expired
                }
            }
        }

        public let accountId: Int
        public let blockTime: TimeInterval?
        public let expiryHeight: BlockHeight?
        public let fee: Zatoshi?
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
        public let isExpiredUmined: Bool?
    }

    public struct Output {
        public enum Pool {
            case transaparent
            case sapling
            case other(Int)
            init(rawValue: Int) {
                switch rawValue {
                case 0:
                    self = .transaparent
                case 2:
                    self = .sapling
                default:
                    self = .other(rawValue)
                }
            }
        }

        public let rawID: Data
        public let pool: Pool
        public let index: Int
        public let fromAccount: Int?
        public let recipient: TransactionRecipient
        public let value: Zatoshi
        public let isChange: Bool
        public let memo: Memo?
    }

    /// Used when fetching blocks from the lightwalletd
    struct Fetched {
        public let rawID: Data
        public let minedHeight: BlockHeight
        public let raw: Data
    }
}

extension ZcashTransaction.Output {
    enum Column {
        static let rawID = Expression<Blob>("txid")
        static let pool = Expression<Int>("output_pool")
        static let index = Expression<Int>("output_index")
        static let toAccount = Expression<Int?>("to_account_id")
        static let fromAccount = Expression<Int?>("from_account_id")
        static let toAddress = Expression<String?>("to_address")
        static let value = Expression<Int64>("value")
        static let isChange = Expression<Bool>("is_change")
        static let memo = Expression<Blob?>("memo")
    }

    init(row: Row) throws {
        do {
            rawID = Data(blob: try row.get(Column.rawID))
            pool = .init(rawValue: try row.get(Column.pool))
            index = try row.get(Column.index)
            fromAccount = try row.get(Column.fromAccount)
            value = Zatoshi(try row.get(Column.value))
            isChange = try row.get(Column.isChange)
            
            if
                let outputRecipient = try row.get(Column.toAddress),
                let metadata = DerivationTool.getAddressMetadata(outputRecipient)
            {
                recipient = TransactionRecipient.address(try Recipient(outputRecipient, network: metadata.networkType))
            } else if let toAccount = try row.get(Column.toAccount) {
                recipient = .internalAccount(UInt32(toAccount))
            } else {
                throw ZcashError.zcashTransactionOutputInconsistentRecipient
            }

            if let memoData = try row.get(Column.memo) {
                memo = try Memo(bytes: memoData.bytes)
            } else {
                memo = nil
            }
        } catch {
            throw ZcashError.zcashTransactionOutputInit(error)
        }
    }
}

extension ZcashTransaction.Overview {
    enum Column {
        static let accountId = Expression<Int>("account_id")
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
        static let expiredUnmined = Expression<Bool?>("expired_unmined")
    }

    init(row: Row) throws {
        do {
            self.accountId = try row.get(Column.accountId)
            self.expiryHeight = try row.get(Column.expiryHeight)
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

/// extension to handle pending states
public extension ZcashTransaction.Overview {
    func getState(for currentHeight: BlockHeight) -> State {
        State(
            currentHeight: currentHeight,
            minedHeight: minedHeight,
            expiredUnmined: self.isExpiredUmined
        )
    }

    func isPending(currentHeight: BlockHeight) -> Bool {
        getState(for: currentHeight) == .pending
    }
}

/**
Capabilities of an entity that can be uniquely identified by a raw transaction id
*/
public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}
