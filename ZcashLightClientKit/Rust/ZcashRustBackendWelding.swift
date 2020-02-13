//
//  ZcashRustBackendWelding.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public enum RustWeldingError: Error {
    case genericError(message: String)
    case dataDbInitFailed(message: String)
    case dataDbNotEmpty
    case saplingSpendParametersNotFound
}

public struct ZcashRustBackendWeldingConstants {
    static let validChain: Int32 = -1
}

public protocol ZcashRustBackendWelding {
    /**
     gets the latest error if available
     */
    static func lastError() -> RustWeldingError?
    /**
     gets the latest error message from librustzcash
     */
    static func getLastError() -> String?
/**
     initializes the data db
     - Parameter dbData: location of the data db sql file
     */
    static func initDataDb(dbData: URL) throws
    /**
    initialize the blocks table from a given checkpoint (birthday)
     - Parameters:
       - dbData: location of the data db
       - seed: byte array of the zip32 seed
       - accounts: how many accounts you want to have
 */
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]?
    
    /**
    initialize the blocks table from a given checkpoint (birthday)
     - Parameters:
       - dbData: location of the data db
       - height: represents the block height of the given checkpoint
       - hash: hash of the merkle tree
       - time: in milliseconds from reference
       - saplingTree: hash of the sapling tree
     */
    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String) throws

    static func getAddress(dbData: URL, account: Int32) -> String?
    /**
    get the (unverified) balance from the given account
    - Parameters:
       - dbData: location of the data db
       - account: index of the given account
    */
    static func getBalance(dbData: URL, account: Int32) -> Int64
    /**
     get the verified balance from the given account
     - Parameters:
        - dbData: location of the data db
        - account: index of the given account
     */
    static func getVerifiedBalance(dbData: URL, account: Int32) -> Int64
    /**
    get received memo from note
    - Parameters:
       - dbData: location of the data db file
       - idNote: note_id of note where the memo is located
    */
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64) -> String?
    
    /**
     get sent memo from note
     - Parameters:
        - dbData: location of the data db file
        - idNote: note_id of note where the memo is located
     */
    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64) -> String?
    
    /**
    * Checks that the scanned blocks in the data database, when combined with the recent
    * `CompactBlock`s in the cache database, form a valid chain.
    * This function is built on the core assumption that the information provided in the
    * cache database is more likely to be accurate than the previously-scanned information.
    * This follows from the design (and trust) assumption that the `lightwalletd` server
    * provides accurate block information as of the time it was requested.
    * Returns:
    * - `-1` if the combined chain is valid.
    * - `upper_bound` if the combined chain is invalid.
    * `upper_bound` is the height of the highest invalid block (on the assumption that the
    * highest block in the cache database is correct).
    * - `0` if there was an error during validation unrelated to chain validity.
    * This function does not mutate either of the databases.
    */
    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32
    /**
     rewinds the compact block storage to the given height. clears up all derived data as well
      - Parameters:
        - dbData: location of the data db file
        - height: height to rewind to
     */
    static func rewindToHeight(dbData: URL, height: Int32) -> Bool
    
    /**
     Scans new blocks added to the cache for any transactions received by the tracked
     accounts.
     This function pays attention only to cached blocks with heights greater than the
     highest scanned block in `db_data`. Cached blocks with lower heights are not verified
     against previously-scanned blocks. In particular, this function **assumes** that the
     caller is handling rollbacks.
     For brand-new light client databases, this function starts scanning from the Sapling
     activation height. This height can be fast-forwarded to a more recent block by calling
     [`zcashlc_init_blocks_table`] before this function.
     Scanned blocks are required to be height-sequential. If a block is missing from the
     cache, an error will be signalled.
     
     - Parameters:
        - dbCache: location of the compact block cache db
        - dbData:  location of the data db file
     returns false if fails to scan.
    */
    static func scanBlocks(dbCache: URL, dbData: URL) -> Bool
    
    /**
     Creates a transaction to the given address from the given account
     - Parameters:
        - dbData: URL for the Data DB
        - account: the account index that will originate the transaction
        - extsk: extended spending key string
        - to: recipient address
        - value: transaction amount in Zatoshi
        - memo: the memo string for this transaction
        - spendParamsPath: path escaped String for the filesystem locations where the spend paremeters are located
        - outputParamsPath: path escaped String for the filesystem locations where the output paremeters are located
     */
    static func createToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String) -> Int64

}
