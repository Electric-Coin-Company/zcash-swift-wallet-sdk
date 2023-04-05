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
    /// Thrown when `upperBound` if the combined chain is invalid. `upperBound` is the height of the highest invalid block (on the assumption that
    /// the highest block in the cache database is correct).
    case invalidChain(upperBound: Int32)
    /// Thrown if there was an error during validation unrelated to chain validity.
    case chainValidationFailed(message: String?)
    /// Thrown if there was problem with memory allocation on the Swift side while trying to write blocks metadata to DB.
    case writeBlocksMetadataAllocationProblem
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

// sourcery: mockActor
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
    /// - parameter seed: byte array of the zip32 seed
    /// - parameter networkType: network type of this key
    /// - Returns: The `UnifiedSpendingKey` structs for the number of accounts created
    ///
    func createAccount(seed: [UInt8]) async throws -> UnifiedSpendingKey

    /// Creates a transaction to the given address from the given account
    /// - Parameter dbData: URL for the Data DB
    /// - Parameter usk: `UnifiedSpendingKey` for the account that controls the funds to be spent.
    /// - Parameter to: recipient address
    /// - Parameter value: transaction amount in Zatoshi
    /// - Parameter memo: the `MemoBytes` for this transaction. pass `nil` when sending to transparent receivers
    /// - Parameter spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
    /// - Parameter outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
    /// - Parameter networkType: network type of this key
    func createToAddress(
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?
    ) async throws -> Int64

    /// Scans a transaction for any information that can be decrypted by the accounts in the
    /// wallet, and saves it to the wallet.
    /// - parameter dbData: location of the data db file
    /// - parameter tx:     the transaction to decrypt
    /// - parameter minedHeight: height on which this transaction was mined. this is used to fetch the consensus branch ID.
    /// - parameter networkType: network type of this key
    /// returns false if fails to decrypt.
    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws

    /// Derives and returns a unified spending key from the given seed for the given account ID.
    /// Returns the binary encoding of the spending key. The caller should manage the memory of (and store, if necessary) the returned spending key in a secure fashion.
    /// - Parameter seed: a Byte Array with the seed
    /// - Parameter accountIndex:account index that the key can spend from
    /// - Parameter networkType: network type of this key
    /// - Throws `.unableToDerive` when there's an error
    func deriveUnifiedSpendingKey(from seed: [UInt8], accountIndex: Int32) async throws -> UnifiedSpendingKey

    /// get the (unverified) balance from the given account
    /// - parameter dbData: location of the data db
    /// - parameter account: index of the given account
    /// - parameter networkType: network type of this key
    func getBalance(account: Int32) async throws -> Int64

    /// Returns the most-recently-generated unified payment address for the specified account.
    /// - parameter dbData: location of the data db
    /// - parameter account: index of the given account
    /// - parameter networkType: network type of this key
    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress

    /// Wallets might need to be rewound because of a reorg, or by user request.
    /// There are times where the wallet could get out of sync for many reasons and
    /// users might be asked to rescan their wallets in order to fix that. This function
    /// returns the nearest height where a rewind is possible. Currently pruning gets rid
    /// of sapling witnesses older than 100 blocks. So in order to reconstruct the witness
    /// tree that allows to spend notes from the given wallet the rewind can't be more than
    /// 100 blocks or back to the oldest unspent note that this wallet contains.
    /// - parameter dbData: location of the data db file
    /// - parameter height: height you would like to rewind to.
    /// - parameter networkType: network type of this key]
    /// - Returns: the blockheight of the nearest rewind height.
    ///
    func getNearestRewindHeight(height: Int32) async throws -> Int32

    /// Returns a newly-generated unified payment address for the specified account, with the next available diversifier.
    /// - parameter dbData: location of the data db
    /// - parameter account: index of the given account
    /// - parameter networkType: network type of this key
    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress

    /// get received memo from note
    /// - parameter dbData: location of the data db file
    /// - parameter idNote: note_id of note where the memo is located
    /// - parameter networkType: network type of this key
    func getReceivedMemo(idNote: Int64) async -> Memo?

    /// Returns the Sapling receiver within the given Unified Address, if any.
    /// - Parameter uAddr: a `UnifiedAddress`
    /// - Returns a `SaplingAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    static func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress

    /// get sent memo from note
    /// - parameter dbData: location of the data db file
    /// - parameter idNote: note_id of note where the memo is located
    /// - parameter networkType: network type of this key
    /// - Returns: a `Memo` if any
    func getSentMemo(idNote: Int64) async -> Memo?

    /// Get the verified cached transparent balance for the given address
    /// - parameter dbData: location of the data db file
    /// - parameter account; the account index to query
    /// - parameter networkType: network type of this key
    func getTransparentBalance(account: Int32) async throws -> Int64

    /// Returns the transparent receiver within the given Unified Address, if any.
    /// - parameter uAddr: a `UnifiedAddress`
    /// - Returns a `TransparentAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    static func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress

    /// initialize the accounts table from a set of unified full viewing keys
    /// - Note: this function should only be used when restoring an existing seed phrase.
    /// when creating a new wallet, use `createAccount()` instead
    /// - Parameter dbData: location of the data db
    /// - Parameter ufvks: an array of UnifiedFullViewingKeys
    /// - Parameter networkType: network type of this key
    func initAccountsTable(ufvks: [UnifiedFullViewingKey]) async throws

    /// initializes the data db. This will performs any migrations needed on the sqlite file
    /// provided. Some migrations might need that callers provide the seed bytes.
    /// - Parameter dbData: location of the data db sql file
    /// - Parameter seed: ZIP-32 compliant seed bytes for this wallet
    /// - Parameter networkType: network type of this key
    /// - Returns: `DbInitResult.success` if the dataDb was initialized successfully
    /// or `DbInitResult.seedRequired` if the operation requires the seed to be passed
    /// in order to be completed successfully.
    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult

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
    static func isValidUnifiedFullViewingKey(_ ufvk: String, networkType: NetworkType) -> Bool

    /// initialize the blocks table from a given checkpoint (heigh, hash, time, saplingTree and networkType)
    /// - parameter dbData: location of the data db
    /// - parameter height: represents the block height of the given checkpoint
    /// - parameter hash: hash of the merkle tree
    /// - parameter time: in milliseconds from reference
    /// - parameter saplingTree: hash of the sapling tree
    /// - parameter networkType: `NetworkType` signaling testnet or mainnet
    func initBlocksTable(
        height: Int32,
        hash: String,
        time: UInt32,
        saplingTree: String
    ) async throws

    /// Returns a list of the transparent receivers for the diversified unified addresses that have
    /// been allocated for the provided account.
    /// - parameter dbData: location of the data db
    /// - parameter account: index of the given account
    /// - parameter networkType: the network type
    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress]

    /// get the verified balance from the given account
    /// - parameter dbData: location of the data db
    /// - parameter account: index of the given account
    /// - parameter networkType: the network type
    func getVerifiedBalance(account: Int32) async throws -> Int64

    /// Get the verified cached transparent balance for the given account
    /// - parameter dbData: location of the data db
    /// - parameter account: account index to query the balance for.
    /// - parameter networkType: the network type
    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64

    /// Checks that the scanned blocks in the data database, when combined with the recent
    /// `CompactBlock`s in the cache database, form a valid chain.
    /// This function is built on the core assumption that the information provided in the
    /// cache database is more likely to be accurate than the previously-scanned information.
    /// This follows from the design (and trust) assumption that the `lightwalletd` server
    /// provides accurate block information as of the time it was requested.
    /// - parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - parameter dbData: location of the data db file
    /// - parameter networkType: the network type
    /// - parameter limit: a limit to validate a fixed number of blocks instead of the whole cache.
    /// - Returns:
    ///  - `-1` if the combined chain is valid.
    ///  - `upper_bound` if the combined chain is invalid.
    ///  - `upper_bound` is the height of the highest invalid block (on the assumption that the highest block in the cache database is correct).
    ///  - `0` if there was an error during validation unrelated to chain validity.
    /// - Important: This function does not mutate either of the databases.
    func validateCombinedChain(limit: UInt32) async throws

    /// Resets the state of the database to only contain block and transaction information up to the given height. clears up all derived data as well
    /// - parameter dbData: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - parameter height: height to rewind to.
    func rewindToHeight(height: Int32) async throws

    /// Resets the state of the FsBlock database to only contain block and transaction information up to the given height.
    /// - Note: this does not delete the files. Only rolls back the database.
    /// - parameter fsBlockDbRoot: location of the data db file
    /// - parameter height: height to rewind to. DON'T PASS ARBITRARY HEIGHT. Use getNearestRewindHeight when unsure
    /// - parameter networkType: the network type
    func rewindCacheToHeight(height: Int32) async throws

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
    /// - parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - parameter dbData: location of the data db sqlite file
    /// - parameter limit: scan up to limit blocks. pass 0 to set no limit.
    /// - parameter networkType: the network type
    /// returns false if fails to scan.
    func scanBlocks(limit: UInt32) async throws

    /// Upserts a UTXO into the data db database
    /// - parameter dbData: location of the data db file
    /// - parameter txid: the txid bytes for the UTXO
    /// - parameter index: the index of the UTXO
    /// - parameter script: the script of the UTXO
    /// - parameter value: the value of the UTXO
    /// - parameter height: the mined height for the UTXO
    /// - parameter networkType: the network type
    func putUnspentTransparentOutput(
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight
    ) async throws

    /// Creates a transaction to shield all found UTXOs in data db for the account the provided `UnifiedSpendingKey` has spend authority for.
    /// - Parameter dbData: URL for the Data DB
    /// - Parameter usk: `UnifiedSpendingKey` that spend transparent funds and where the funds will be shielded to.
    /// - Parameter memo: the `Memo` for this transaction
    /// - Parameter spendParamsPath: path escaped String for the filesystem locations where the spend parameters are located
    /// - Parameter outputParamsPath: path escaped String for the filesystem locations where the output parameters are located
    /// - Parameter networkType: the network type
    func shieldFunds(
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        shieldingThreshold: Zatoshi
    ) async throws -> Int64

    /// Obtains the available receiver typecodes for the given String encoded Unified Address
    /// - Parameter address: public key represented as a String
    /// - Returns  the `[UInt32]` that compose the given UA
    /// - Throws `RustWeldingError.invalidInput(message: String)` when the UA is either invalid or malformed
    static func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32]

    /// Gets the consensus branch id for the given height
    /// - Parameter height: the height you what to know the branch id for
    /// - Parameter networkType: the network type
    func consensusBranchIdFor(height: Int32) async throws -> Int32

    /// Derives a `UnifiedFullViewingKey` from a `UnifiedSpendingKey`
    /// - Parameter spendingKey: the `UnifiedSpendingKey` to derive from
    /// - Parameter networkType: the network type
    /// - Throws: `RustWeldingError.unableToDeriveKeys` if the SDK couldn't derive the UFVK.
    /// - Returns: the derived `UnifiedFullViewingKey`
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) async throws -> UnifiedFullViewingKey

    /// initializes Filesystem based block cache
    /// - Parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - throws `RustWeldingError` when fails to initialize
    func initBlockMetadataDb() async throws

    /// Write compact block metadata to a database known to the Rust layer
    /// - Parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - Parameter blocks: The `ZcashCompactBlock`s that are going to be marked as stored by the
    /// metadata Db.
    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws

    /// Gets the latest block height stored in the filesystem based cache.
    /// -  Parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - Returns `BlockHeight` of the latest cached block or `.empty` if no blocks are stored.
    func latestCachedBlockHeight() async -> BlockHeight
}
