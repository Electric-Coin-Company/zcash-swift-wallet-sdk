//
//  BlockDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

protocol BlockDao {
    func latestBlockHeight() throws -> BlockHeight
    func latestBlock() throws -> Block?
    func block(at height: BlockHeight) throws -> Block?
}

struct Block: Codable {
    enum CodingKeys: String, CodingKey {
        case height
        case hash
        case time
        case saplingTree = "sapling_tree"
    }

    enum TableStructure {
        static let height = Expression<Int>(Block.CodingKeys.height.rawValue)
        static let hash = Expression<Blob>(Block.CodingKeys.hash.rawValue)
        static let time = Expression<Int>(Block.CodingKeys.time.rawValue)
        static let saplingTree = Expression<Blob>(Block.CodingKeys.saplingTree.rawValue)
    }

    let height: BlockHeight
    let hash: Data
    let time: Int
    let saplingTree: Data

    static let table = Table("blocks")
}

struct VTransaction: Codable {
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case idTx = "id_tx"
        case minedHeight = "mined_height"
        case txIndex = "tx_index"
        case txId = "txid"
        case expiryHeight = "expiry_height"
        case raw = "raw"
        case accountBalanceDelta = "account_balance_delta"
        case feePaid = "fee_paid"
        case expiredUnmined = "expired_unmined"
        case hasChange = "has_change"
        case sentNoteCount = "sent_note_count"
        case recievedNoteCount = "received_note_count"
        case memoCount = "memo_count"
        case blockTime = "block_time"
    }

    enum TableStructure {
        static let accountId = Expression<Int>(VTransaction.CodingKeys.accountId.rawValue)
        static let idTx = Expression<Int>(VTransaction.CodingKeys.idTx.rawValue)
        static let minedHeight = Expression<Int>(VTransaction.CodingKeys.minedHeight.rawValue)
        static let txIndex = Expression<Int>(VTransaction.CodingKeys.txIndex.rawValue)
        static let txId = Expression<Data>(VTransaction.CodingKeys.txId.rawValue)
        static let expiryHeight = Expression<Int?>(VTransaction.CodingKeys.expiryHeight.rawValue)
        static let raw = Expression<Data?>(VTransaction.CodingKeys.raw.rawValue)
        static let accountBalanceDelta = Expression<Int>(VTransaction.CodingKeys.accountBalanceDelta.rawValue)
        static let feePaid = Expression<Int?>(VTransaction.CodingKeys.feePaid.rawValue)
        static let expiredUnmined = Expression<Int>(VTransaction.CodingKeys.expiredUnmined.rawValue)
        static let hasChange = Expression<Bool>(VTransaction.CodingKeys.hasChange.rawValue)
        static let sentNoteCount = Expression<Int>(VTransaction.CodingKeys.sentNoteCount.rawValue)
        static let recievedNoteCount = Expression<Int>(VTransaction.CodingKeys.recievedNoteCount.rawValue)
        static let memoCount = Expression<Int>(VTransaction.CodingKeys.memoCount.rawValue)
        static let blockTime = Expression<Int>(VTransaction.CodingKeys.blockTime.rawValue)
    }

    let accountId: Int
    let idTx: Int
    let minedHeight: Int
    let txIndex: Int
    let txId: Data
    let expiryHeight: Int?
    let raw: Data?
    let accountBalanceDelta: Int
    let feePaid: Int?
    let expiredUnmined: Int
    let hasChange: Bool
    let sentNoteCount: Int
    let recievedNoteCount: Int
    let memoCount: Int
    let blockTime: Int

    static let table = Table("v_transactions")
}

class BlockSQLDAO: BlockDao {
    let dbProvider: ConnectionProvider
    let table: Table
    let height = Expression<Int>("height")

    let minedHeight = Expression<Int>("mined_height")
    let raw = Expression<Data?>("raw")

    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
        self.table = Table("Blocks")
    }

    /// - Throws:
    ///     - `blockDAOCantDecode` if block data loaded from DB can't be decoded to `Block` object.
    ///     - `blockDAOBlock` if sqlite query to load block metadata failed.
    func block(at height: BlockHeight) throws -> Block? {
        do {
            return try dbProvider
                .connection()
                .prepare(Block.table.filter(Block.TableStructure.height == height).limit(1))
                .map {
                    do {
                        return try $0.decode()
                    } catch {
                        throw ZcashError.blockDAOCantDecode(error)
                    }
                }
                .first
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.blockDAOBlock(error)
            }
        }
    }

    /// - Throws: `blockDAOLatestBlockHeight` if sqlite to fetch height fails.
    func latestBlockHeight() throws -> BlockHeight {
        do {
            return try dbProvider.connection().scalar(table.select(height.max)) ?? BlockHeight.empty()
        } catch {
            throw ZcashError.blockDAOLatestBlockHeight(error)
        }
    }
    
    func latestBlock() throws -> Block? {
        do {
            return try dbProvider
                .connection()
                .prepare(Block.table.order(height.desc).limit(1))
                .map {
                    do {
                        return try $0.decode()
                    } catch {
                        throw ZcashError.blockDAOLatestBlockCantDecode(error)
                    }
                }
                .first
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.blockDAOLatestBlock(error)
            }
        }
    }
    
    func firstUnenhancedHeight(in range: CompactBlockRange? = nil) throws -> BlockHeight? {
        do {
            return try dbProvider
                .connection()
                .prepare(
                    VTransaction.table
                        .order(minedHeight.asc)
                        .filter(raw == nil)
                        .limit(1)
                )
                .map {
                    do {
                        let vTransaction: VTransaction = try $0.decode()
                        return vTransaction.minedHeight
                    } catch {
                        throw ZcashError.blockDAOFirstUnenhancedCantDecode(error)
                    }
                }
                .first
        } catch {
            throw ZcashError.blockDAOFirstUnenhancedHeight(error)
        }
    }
}

extension BlockSQLDAO: BlockRepository {
    func lastScannedBlockHeight() -> BlockHeight {
        (try? self.latestBlockHeight()) ?? BlockHeight.empty()
    }
}
