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
    case malformedStringInput
    case noConsensusBranchId(height: Int32)
    case unableToDeriveKeys
}

public struct ZcashRustBackendWeldingConstants {
    static let validChain: Int32 = -1
}

public protocol ZcashRustBackendWelding {
    /**
     gets the latest error if available. Clear the existing error
     */
    static func lastError() -> RustWeldingError?
    /**
     gets the latest error message from librustzcash. Does not clear existing error
     */
    static func getLastError() -> String?
/**
     initializes the data db
     - Parameter dbData: location of the data db sql file
     */
    static func initDataDb(dbData: URL) throws
    
    /**
    - Returns: true when the address is valid and shielded. Returns false in any other case
    - Throws: Error when the provided address belongs to another network
    */
    static func isValidShieldedAddress(_ address: String) throws -> Bool
    
    /**
     - Returns: true when the address is valid and transparent. false in any other case
     - Throws: Error when the provided address belongs to another network
    */
    static func isValidTransparentAddress(_ address: String) throws -> Bool
    
    /**
     - Returns: true when the address is valid and transparent. false in any other case
     - Throws: Error when there's another problem not related to validity of the string in question
    */
    static func isValidExtendedFullViewingKey(_ key: String) throws -> Bool
    
    /**
    initialize the accounts table from a given seed and a number of accounts
     - Parameters:
       - dbData: location of the data db
       - seed: byte array of the zip32 seed
       - accounts: how many accounts you want to have
 */
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]?
    
    /**
     initialize the accounts table from a set of unified viewing keys
     - Parameters:
       - dbData: location of the data db
       - uvks: an array of UnifiedViewingKeys 
     */
    static func initAccountsTable(dbData: URL, uvks: [UnifiedViewingKey]) throws -> Bool

    
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

    /**
     gets the address from data db from the given account
     - Parameters:
       - dbData: location of the data db
       - account: index of the given account
     - Returns: an optional string with the address if found
     */
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
     Get the verified cached transparent balance for the given address
     */
    static func getVerifiedTransparentBalance(dbData: URL, address: String) throws -> Int64
    
    /**
     Get the verified cached transparent balance for the given address
     */
    static func getTransparentBalance(dbData: URL, address: String) throws -> Int64 
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
     Checks that the scanned blocks in the data database, when combined with the recent
     `CompactBlock`s in the cache database, form a valid chain.
     This function is built on the core assumption that the information provided in the
     cache database is more likely to be accurate than the previously-scanned information.
     This follows from the design (and trust) assumption that the `lightwalletd` server
     provides accurate block information as of the time it was requested.
- Returns:
     * `-1` if the combined chain is valid.
     * `upper_bound` if the combined chain is invalid.
     * `upper_bound` is the height of the highest invalid block (on the assumption that the highest block in the cache database is correct).
     * `0` if there was an error during validation unrelated to chain validity.
     - Important: This function does not mutate either of the databases.
    */
    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32
    
    /**
     Returns the nearest height where a rewind is possible. Currently prunning gets rid of sapling witnesses older
     than 100 blocks. So in order to reconstruct the witness tree that allows to spend notes from the given wallet
     the rewind can't be more than 100 block or back to the oldest unspent note that this wallet contains.
     - Parameters:
       - dbData: location of the data db file
       - height: height you would like to rewind to.
     */
    static func getNearestRewindHeight(dbData: URL, height: Int32) -> Int32
    /**
     rewinds the compact block storage to the given height. clears up all derived data as well
      - Parameters:
        - dbData: location of the data db file
        - height: height to rewind to. DON'T PASS ARBITRARY HEIGHT. Use getNearestRewindHeight when unsure
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
     puts a UTXO into the data db database
     - Parameters:
       - dbData: location of the data db file
       - address: the address of the UTXO
       - txid: the txid bytes for the UTXO
       - index: the index of the UTXO
       - value: the value of the UTXO
       - height: the mined height for the UTXO
     - Returns: true if the operation succeded or false otherwise
     */
    static func putUnspentTransparentOutput(dbData: URL, address: String, txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight) throws -> Bool
    
    
    /**
     clears the cached utxos for the given address from the specified height on
     - Parameters:
      - dbData: location of the data db file
      - address: the address of the UTXO
      - sinceheight: clear the UXTOs from that address on
     - Returns: the amount of UTXOs cleared or -1 on error
     
     */
    static func clearUtxos(dbData: URL, address: String, sinceHeight: BlockHeight) throws -> Int32
    /**
        Gets the balance of the previously downloaded UTXOs
     - Parameters:
       - dbData: location of the data db file
       - address: the address of the UTXO
     - Returns: the wallet balance containing verified and total balance.
     - Throws: Rustwelding Error if something fails
     */
    static func downloadedUtxoBalance(dbData: URL, address: String) throws -> WalletBalance
    
    /**
     Scans a transaction for any information that can be decrypted by the accounts in the
     wallet, and saves it to the wallet.

     - Parameters:
        - dbData: location of the data db file
        - tx:     the transaction to decrypt
     returns false if fails to decrypt.
     */
    static func decryptAndStoreTransaction(dbData: URL, tx: [UInt8]) -> Bool
    
    /**
     Creates a transaction to the given address from the given account
     - Parameters:
        - dbData: URL for the Data DB
        - account: the account index that will originate the transaction
        - extsk: extended spending key string
        - to: recipient address
        - value: transaction amount in Zatoshi
        - memo: the memo string for this transaction
        - spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
        - outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
     */
    static func createToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String) -> Int64
    
    /**
     Creates a transaction to shield all found UTXOs in cache db.
     - Parameters:
        - dbCache: URL for the Cache DB
        - dbData: URL for the Data DB
        - account: the account index that will originate the transaction
        - tsk: transparent Secret Key for the shielded funds.
        - extsk: extended spending key string
        - memo: the memo string for this transaction
        - spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
        - outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
     */
    static func shieldFunds(dbCache: URL, dbData: URL, account: Int32, tsk: String, extsk: String, memo: String?, spendParamsPath: String, outputParamsPath: String) -> Int64
    
    /**
     Derives a full viewing key from a seed
     - Parameter spendingKey: a string containing the spending key
     - Returns: the derived key
     - Throws: RustBackendError if fatal error occurs
     */
    static func deriveExtendedFullViewingKey(_ spendingKey: String) throws -> String?
    
    /**
    Derives a set of full viewing keys from a seed
    - Parameter spendingKey: a string containing the spending key
    - Parameter accounts: the number of accounts you want to derive from this seed
    - Returns: an array containing the derived keys
    - Throws: RustBackendError if fatal error occurs
    */
    static func deriveExtendedFullViewingKeys(seed: [UInt8], accounts: Int32) throws -> [String]?
    
    /**
    Derives a set of full viewing keys from a seed
    - Parameter seed: a string containing the seed
    - Parameter accounts: the number of accounts you want to derive from this seed
    - Returns: an array containing the spending keys
    - Throws: RustBackendError if fatal error occurs
    */
    static func deriveExtendedSpendingKeys(seed: [UInt8], accounts: Int32) throws -> [String]?
    
    /**
     Derives a shielded address from a seed
     - Parameter seed: an array of bytes of the seed
     - Parameter accountIndex: the index of the account you want the address for
     - Returns: an optional String containing the Shielded address
     - Throws: RustBackendError if fatal error occurs
     */
    static func deriveShieldedAddressFromSeed(seed: [UInt8], accountIndex: Int32) throws -> String?
    
    /**
     Derives a shielded address from an Extended Full Viewing Key
     - Parameter extfvk: a string containing the extended full viewing key
     - Returns: an optional String containing the Shielded address
     - Throws: RustBackendError if fatal error occurs
     */
    static func deriveShieldedAddressFromViewingKey(_  extfvk: String) throws -> String?
    
    /**
     Derives a shielded address from an Extended Full Viewing Key
     - Parameter seed: an array of bytes of the seed
     - Returns: an optional String containing the transparent address
     - Throws: RustBackendError if fatal error occurs
     */
    static func deriveTransparentAddressFromSeed(seed: [UInt8], account: Int, index: Int) throws -> String?
    
    /**
        Derives a transparent secret key from Seed
      - Parameter seed: an array of bytes containing the seed
      - Returns: an optional String containing the transparent secret (private) key
     */
    static func deriveTransparentPrivateKeyFromSeed(seed: [UInt8], account: Int, index: Int) throws -> String?
    
    /**
        Derives a transparent address from a secret key
     - Parameter tsk: a hex string containing the Secret Key
     - Returns: an optional String containing the transparent address.
     */
    
    static func deriveTransparentAddressFromSecretKey(_ tsk: String) throws -> String?
    
    /**
     Derives a tranparent address from a public key
      - Parameter pubkey: public key represented as a string
     */
    static func derivedTransparentAddressFromPublicKey(_ pubkey: String) throws -> String
    
    static func deriveUnifiedViewingKeyFromSeed(_ seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedViewingKey]
    /**
     Gets the consensus branch id for the given height
     - Parameter height: the height you what to know the branch id for
     */
    static func consensusBranchIdFor(height: Int32) throws -> Int32
}
