//
//  ZcashRustBackendWelding.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum RustWeldingError: Error {
    case genericError(message: String)
    case dataDbInitFailed(message: String)
    case dataDbNotEmpty
    case saplingSpendParametersNotFound
    case malformedStringInput
    case noConsensusBranchId(height: Int32)
    case unableToDeriveKeys
    case getBalanceError(Int, Error)
    case invalidInput(message: String)
    case invalidRewind(suggestedHeight: Int32)
}

enum ZcashRustBackendWeldingConstants {
    static let validChain: Int32 = -1
}
/// Enumeration of potential return states for database initialization. If `seedRequired`
/// is returned, the caller must re-attempt initialization providing the seed
public enum DbInitResult {
    case success
    case seedRequired
}

protocol ZcashRustBackendWelding {
    /// Adds the next available account-level spend authority, given the current set of [ZIP 316]
    /// account identifiers known, to the wallet database.
    ///
    /// Returns the newly created [ZIP 316] account identifier, along with the binary encoding of the
    /// [`UnifiedSpendingKey`] for the newly created account.  The caller should manage the memory of
    /// (and store) the returned spending keys in a secure fashion.
    ///
    /// If `seed` was imported from a backup and this method is being used to restore a
    /// previous wallet state, you should use this method to add all of the desired
    /// accounts before scanning the chain from the seed's birthday height.
    ///
    /// By convention, wallets should only allow a new account to be generated after funds
    /// have been received by the currently-available account (in order to enable
    /// automated account recovery).
    /// - Parameters:
    ///    - dbData: location of the data db
    ///    - seed: byte array of the zip32 seed
    ///    - networkType: network type of this key
    /// - Returns: The `UnifiedSpendingKey` structs for the number of accounts created
    ///
    static func createAccount(
        dbData: URL,
        seed: [UInt8],
        networkType: NetworkType
    ) throws -> UnifiedSpendingKey

    /// Creates a transaction to the given address from the given account
    /// - Parameter dbData: URL for the Data DB
    /// - Parameter usk: `UnifiedSpendingKey` for the account that controls the funds to be spent.
    /// - Parameter to: recipient address
    /// - Parameter value: transaction amount in Zatoshi
    /// - Parameter memo: the `MemoBytes` for this transaction. pass `nil` when sending to transparent receivers
    /// - Parameter spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
    /// - Parameter outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
    /// - Parameter networkType: network type of this key
    static func createToAddress(
        dbData: URL,
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 // swiftlint:disable function_parameter_count

    /// Scans a transaction for any information that can be decrypted by the accounts in the
    /// wallet, and saves it to the wallet.
    ///
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - tx:     the transaction to decrypt
    ///   - minedHeight: height on which this transaction was mined. this is used to fetch the consensus branch ID.
    ///   - networkType: network type of this key
    /// returns false if fails to decrypt.
    static func decryptAndStoreTransaction(
        dbData: URL,
        txBytes: [UInt8],
        minedHeight: Int32,
        networkType: NetworkType
    ) -> Bool

     /// Derives and returns a unified spending key from the given seed for the given account ID.
     /// Returns the binary encoding of the spending key. The caller should manage the memory of (and store, if necessary) the returned spending key in a secure fashion.
    /// - Parameter seed: a Byte Array with the seed
    /// - Parameter accountIndex:account index that the key can spend from
    /// - Parameter networkType: network type of this key
    /// - Throws `.unableToDerive` when there's an error
    static func deriveUnifiedSpendingKey(
        from seed: [UInt8],
        accountIndex: Int32,
        networkType: NetworkType
    ) throws -> UnifiedSpendingKey

    /// get the (unverified) balance from the given account
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: index of the given account
    ///   - networkType: network type of this key
    static func getBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64

    /// Returns the most-recently-generated unified payment address for the specified account.
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: index of the given account
    ///   - networkType: network type of this key
    static func getCurrentAddress(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> UnifiedAddress

    /// Wallets might need to be rewound because of a reorg, or by user request.
    /// There are times where the wallet could get out of sync for many reasons and
    /// users might be asked to rescan their wallets in order to fix that. This function
    /// returns the nearest height where a rewind is possible. Currently pruning gets rid
    /// of sapling witnesses older than 100 blocks. So in order to reconstruct the witness
    /// tree that allows to spend notes from the given wallet the rewind can't be more than
    /// 100 blocks or back to the oldest unspent note that this wallet contains.
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - height: height you would like to rewind to.
    ///   - networkType: network type of this key]
    /// - Returns: the blockheight of the nearest rewind height.
    ///
    static func getNearestRewindHeight(
        dbData: URL,
        height: Int32,
        networkType: NetworkType
    ) -> Int32

    /// Returns a newly-generated unified payment address for the specified account, with the next available diversifier.
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: index of the given account
    ///   - networkType: network type of this key
    static func getNextAvailableAddress(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> UnifiedAddress

    /// get received memo from note
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - idNote: note_id of note where the memo is located
    ///   - networkType: network type of this key
    @available(*, deprecated, message: "This function will be deprecated soon. Use `getReceivedMemo(dbData:idNote:networkType)` instead")
    static func getReceivedMemoAsUTF8(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> String?


    /// get received memo from note
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - idNote: note_id of note where the memo is located
    ///   - networkType: network type of this key
    static func getReceivedMemo(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> Memo?

    /// Returns the Sapling receiver within the given Unified Address, if any.
    /// - Parameter uAddr: a `UnifiedAddress`
    /// - Returns a `SaplingAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    static func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress?

    /// get sent memo from note
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - idNote: note_id of note where the memo is located
    ///   - networkType: network type of this key
    @available(*, deprecated, message: "This function will be deprecated soon. Use `getSentMemo(dbData:idNote:networkType)` instead")
    static func getSentMemoAsUTF8(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> String?

    /// get sent memo from note
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - idNote: note_id of note where the memo is located
    ///   - networkType: network type of this key
    /// - Returns: a `Memo` if any
    static func getSentMemo(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> Memo?

    /// Get the verified cached transparent balance for the given address
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - account; the account index to query
    ///   - networkType: network type of this key
    static func getTransparentBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64

    /// Returns the transparent receiver within the given Unified Address, if any.
    // - Parameter uAddr: a `UnifiedAddress`
    /// - Returns a `TransparentAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    static func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress?

    /// gets the latest error if available. Clear the existing error
    ///  - Returns a `RustWeldingError` if exists
    static func lastError() -> RustWeldingError?

    /// gets the latest error message from librustzcash. Does not clear existing error
    static func getLastError() -> String?

    /// initialize the accounts table from a set of unified full viewing keys
    /// - Note: this function should only be used when restoring an existing seed phrase.
    /// when creating a new wallet, use `createAccount()` instead
    /// - Parameter dbData: location of the data db
    /// - Parameter ufvks: an array of UnifiedFullViewingKeys
    /// - Parameter networkType: network type of this key
    static func initAccountsTable(
        dbData: URL,
        ufvks: [UnifiedFullViewingKey],
        networkType: NetworkType
    ) throws

    /// initializes the data db. This will performs any migrations needed on the sqlite file
    /// provided. Some migrations might need that callers provide the seed bytes.
    /// - Parameter dbData: location of the data db sql file
    /// - Parameter seed: ZIP-32 compliant seed bytes for this wallet
    /// - Parameter networkType: network type of this key
    /// - Returns: `DbInitResult.success` if the dataDb was initialized successfully
    /// or `DbInitResult.seedRequired` if the operation requires the seed to be passed
    /// in order to be completed successfully.
    static func initDataDb(
        dbData: URL,
        seed: [UInt8]?,
        networkType: NetworkType
    ) throws -> DbInitResult

    /// Returns the network and address type for the given Zcash address string,
    /// if the string represents a valid Zcash address.
    static func getAddressMetadata(_ address: String) -> AddressMetadata? 

    /// Validates the if the given string is a valid Sapling Address
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Parameter networkType: network type of this key
    /// - Returns: true when the address is valid. Returns false in any other case
    /// - Throws: Error when the provided address belongs to another network
    static func isValidSaplingAddress(_ address: String, networkType: NetworkType) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Full Viewing Key
    /// - Parameter key: UTF-8 encoded String to validate
    /// - Parameter networkType: network type of this key
    /// - Returns: `true` when the Sapling Extended Full Viewing Key is valid. `false` in any other case
    /// - Throws: Error when there's another problem not related to validity of the string in question
    static func isValidSaplingExtendedFullViewingKey(_ key: String, networkType: NetworkType) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Spending Key
    /// - Returns: `true` when the Sapling Extended Spending Key is valid, false in any other case.
    /// - Throws: Error when the key is semantically valid  but it belongs to another network
    /// - parameter key: String encoded Extended Spending Key
    /// - parameter networkType: `NetworkType` signaling testnet or mainnet
    static func isValidSaplingExtendedSpendingKey(_ key: String, networkType: NetworkType) -> Bool

    /// Validates the if the given string is a valid Transparent Address
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Parameter networkType: network type of this key
    /// - Returns: true when the address is valid and transparent. false in any other case
    /// - Throws: Error when the provided address belongs to another network
    static func isValidTransparentAddress(_ address: String, networkType: NetworkType) -> Bool

    /// validates whether a string encoded address is a valid Unified Address.
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Parameter networkType: network type of this key
    /// - Returns: true when the address is valid and transparent. false in any other case
    /// - Throws: Error when the provided address belongs to another network
    static func isValidUnifiedAddress(_ address: String, networkType: NetworkType) -> Bool

    ///  verifies that the given string-encoded `UnifiedFullViewingKey` is valid.
    /// - Parameter ufvk: UTF-8 encoded String to validate
    /// - Parameter networkType: network type of this key
    /// - Returns: true when the encoded string is a valid UFVK. false in any other case
    /// - Throws: Error when there's another problem not related to validity of the string in question
    static func isValidUnifiedFullViewingKey(_ ufvk: String, networkType: NetworkType)  -> Bool

    /// initialize the blocks table from a given checkpoint (height, hash, time, saplingTree and networkType)
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - height: represents the block height of the given checkpoint
    ///   - hash: hash of the merkle tree
    ///   - time: in milliseconds from reference
    ///   - saplingTree: hash of the sapling tree
    ///   - networkType: `NetworkType` signaling testnet or mainnet
    static func initBlocksTable(
        dbData: URL,
        height: Int32,
        hash: String,
        time: UInt32,
        saplingTree: String,
        networkType: NetworkType
    ) throws // swiftlint:disable function_parameter_count

    /// Returns a list of the transparent receivers for the diversified unified addresses that have
    /// been allocated for the provided account.
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: index of the given account
    ///   - networkType: the network type
    static func listTransparentReceivers(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> [TransparentAddress]

    /// get the verified balance from the given account
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: index of the given account
    ///   - networkType: the network type
    static func getVerifiedBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64


    /// Get the verified cached transparent balance for the given account
    /// - Parameters:
    ///   - dbData: location of the data db
    ///   - account: account index to query the balance for.
    ///   - networkType: the network type
    static func getVerifiedTransparentBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64

    /// Checks that the scanned blocks in the data database, when combined with the recent
    /// `CompactBlock`s in the cache database, form a valid chain.
    /// This function is built on the core assumption that the information provided in the
    /// cache database is more likely to be accurate than the previously-scanned information.
    /// This follows from the design (and trust) assumption that the `lightwalletd` server
    /// provides accurate block information as of the time it was requested.
    /// - Parameters:
    ///   - dbCache: location of the cache db file
    ///   - dbData: location of the data db file
    ///   - networkType: the network type
    /// - Returns:
    ///  - `-1` if the combined chain is valid.
    ///  - `upper_bound` if the combined chain is invalid.
    ///  - `upper_bound` is the height of the highest invalid block (on the assumption that the highest block in the cache database is correct).
    ///  - `0` if there was an error during validation unrelated to chain validity.
    /// - Important: This function does not mutate either of the databases.
    static func validateCombinedChain(
        dbCache: URL,
        dbData: URL,
        networkType: NetworkType
    ) -> Int32

    /// Resets the state of the database to only contain block and transaction information up to the given height. clears up all derived data as well
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - height: height to rewind to. DON'T PASS ARBITRARY HEIGHT. Use getNearestRewindHeight when unsure
    ///   - networkType: the network type
    static func rewindToHeight(
        dbData: URL,
        height: Int32,
        networkType: NetworkType
    ) -> Bool
    

    /// Scans new blocks added to the cache for any transactions received by the tracked
    /// accounts.
    /// This function pays attention only to cached blocks with heights greater than the
    /// highest scanned block in `db_data`. Cached blocks with lower heights are not verified
    /// against previously-scanned blocks. In particular, this function **assumes** that the
    /// caller is handling rollbacks.
    /// For brand-new light client databases, this function starts scanning from the Sapling
    /// activation height. This height can be fast-forwarded to a more recent block by calling
    /// [`initBlocksTable`] before this function.
    /// Scanned blocks are required to be height-sequential. If a block is missing from the
    /// cache, an error will be signalled.
    ///
    /// - Parameters:
    ///   - dbCache: location of the compact block cache db
    ///   - dbData:  location of the data db file
    ///   - limit: scan up to limit blocks. pass 0 to set no limit.
    ///   - networkType: the network type
    /// returns false if fails to scan.
    static func scanBlocks(
        dbCache: URL,
        dbData: URL,
        limit: UInt32,
        networkType: NetworkType
    ) -> Bool


    /// puts a UTXO into the data db database
    /// - Parameters:
    ///   - dbData: location of the data db file
    ///   - txid: the txid bytes for the UTXO
    ///   - index: the index of the UTXO
    ///   - script: the script of the UTXO
    ///   - value: the value of the UTXO
    ///   - height: the mined height for the UTXO
    ///   - networkType: the network type
    /// - Returns: true if the operation succeeded or false otherwise
    static func putUnspentTransparentOutput(
        dbData: URL,
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight,
        networkType: NetworkType
    ) throws -> Bool

    /// Creates a transaction to shield all found UTXOs in cache db for the account the provided `UnifiedSpendingKey` has spend authority for.
    /// - Parameter dbCache: URL for the Cache DB
    /// - Parameter dbData: URL for the Data DB
    /// - Parameter usk: `UnifiedSpendingKey` that spend transparent funds and where the funds will be shielded to.
    /// - Parameter memo: the `Memo` for this transaction
    /// - Parameter spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
    /// - Parameter outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
    /// - Parameter networkType: the network type
    static func shieldFunds(
        dbCache: URL,
        dbData: URL,
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 // swiftlint:disable function_parameter_count

    /// Obtains the available receiver typecodes for the given String encoded Unified Address
    /// - Parameter address: public key represented as a String
    /// - Returns  the `[UInt32]` that compose the given UA
    /// - Throws `RustWeldingError.invalidInput(message: String)` when the UA is either invalid or malformed
    static func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32]


    /// Gets the consensus branch id for the given height
    /// - Parameter height: the height you what to know the branch id for
    /// - Parameter networkType: the network type
    static func consensusBranchIdFor(
        height: Int32,
        networkType: NetworkType
    ) throws -> Int32


    /// Derives a `UnifiedFullViewingKey` from a `UnifiedSpendingKey`
    /// - Parameter spendingKey: the `UnifiedSpendingKey` to derive from
    /// - Parameter networkType: the network type
    /// - Throws: `RustWeldingError.unableToDeriveKeys` if the SDK couldn't derive the UFVK.
    /// - Returns: the derived `UnifiedFullViewingKey`
    static func deriveUnifiedFullViewingKey(
        from spendingKey: UnifiedSpendingKey,
        networkType: NetworkType
    ) throws -> UnifiedFullViewingKey
}
