//
//  ZcashErrorDefinition.swift
//  
//
//  Created by Michal Fousek on 10.04.2023.
//

import Foundation

// swiftlint:disable identifier_name

/*
 This enum won't every be directly used in the code. It is just definition of errors and it used as source for Sourcery. And the files used in the
 code are then generated. Check `ZcashError` and `ZcashErrorCode`.

 Please pay attention how each error is defined here. Important part is to raw code for each error. And it's important to use /// for the
 documentation and only // for the sourcery command.

 First line of documentation for each error will be used in automatically generated `message` property.

 Error code should always start with `Z` letter. Then there should be 0-4 letters that marks in which part of the SDK is the code used. And then 4
 numbers. This is suggestion to keep some order when it comes to error codes. Each code must be unique. `ZcashErrorCode` enum is generated from these
 codes. So if the code isn't unique generated code won't compile.
*/

enum ZcashErrorDefinition {
    /// Some error happened that is not handled as `ZcashError`. All errors in the SDK are (should be) `ZcashError`.
    /// This case is ideally not contructed directly or thrown by any SDK function, rather it's a wrapper for case clients expect ZcashErrot and want to pass it to a function/enum.
    /// If this is the case, use `toZcashError()` extension of Error. This helper avoids to end up with Optional handling.
    // sourcery: code="ZUNKWN0001"
    case unknown(_ error: Error)
    
    // MARK: - Initializer

    /// Updating of paths in `Initilizer` according to alias failed.
    // sourcery: code="ZINIT0001"
    case initializerCantUpdateURLWithAlias(_ url: URL)
    /// Alias used to create this instance of the `SDKSynchronizer` is already used by other instance.
    // sourcery: code="ZINIT0002"
    case initializerAliasAlreadyInUse(_ alias: ZcashSynchronizerAlias)

    // MARK: - LightWalletService

    /// Unknown GRPC Service error
    // sourcery: code="ZSRVC0001"
    case serviceUnknownError(_ error: Error)
    /// LightWalletService.getInfo failed.
    // sourcery: code="ZSRVC0002"
    case serviceGetInfoFailed(_ error: LightWalletServiceError)
    /// LightWalletService.latestBlock failed.
    // sourcery: code="ZSRVC0003"
    case serviceLatestBlockFailed(_ error: LightWalletServiceError)
    /// LightWalletService.latestBlockHeight failed.
    // sourcery: code="ZSRVC0004"
    case serviceLatestBlockHeightFailed(_ error: LightWalletServiceError)
    /// LightWalletService.blockRange failed.
    // sourcery: code="ZSRVC0005"
    case serviceBlockRangeFailed(_ error: LightWalletServiceError)
    /// LightWalletService.submit failed.
    // sourcery: code="ZSRVC0006"
    case serviceSubmitFailed(_ error: LightWalletServiceError)
    /// LightWalletService.fetchTransaction failed.
    // sourcery: code="ZSRVC0007"
    case serviceFetchTransactionFailed(_ error: LightWalletServiceError)
    /// LightWalletService.fetchUTXOs failed.
    // sourcery: code="ZSRVC0008"
    case serviceFetchUTXOsFailed(_ error: LightWalletServiceError)
    /// LightWalletService.blockStream failed.
    // sourcery: code="ZSRVC0000"
    case serviceBlockStreamFailed(_ error: LightWalletServiceError)

    // MARK: SQLite connection

    /// SimpleConnectionProvider init of Connection failed.
    // sourcery: code="ZSCPC0001"
    case simpleConnectionProvider(_ error: Error)

    // MARK: - Sapling parameters download

    /// Downloaded file with sapling spending parameters isn't valid.
    // sourcery: code="ZSAPP0001"
    case saplingParamsInvalidSpendParams
    /// Downloaded file with sapling output parameters isn't valid.
    // sourcery: code="ZSAPP0002"
    case saplingParamsInvalidOutputParams
    /// Failed to download sapling parameters file
    /// - `error` is download error.
    /// - `downloadURL` is URL from which was file downloaded.
    // sourcery: code="ZSAPP0003"
    case saplingParamsDownload(_ error: Error, _ downloadURL: URL)
    /// Failed to move sapling parameters file to final destination after download.
    /// - `error` is move error.
    /// - `downloadURL` is URL from which was file downloaded.
    /// - `destination` is filesystem URL pointing to location where downloaded file should be moved.
    // sourcery: code="ZSAPP0004"
    case saplingParamsCantMoveDownloadedFile(_ error: Error, _ downloadURL: URL, _ destination: URL)

    // MARK: - BlockDAO

    /// SQLite query failed when fetching block information from database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZBDAO0001"
    case blockDAOBlock(_ sqliteError: Error)
    /// Fetched block information from DB but can't decode them.
    /// - `error` is decoding error.
    // sourcery: code="ZBDAO0002"
    case blockDAOCantDecode(_ error: Error)
    /// SQLite query failed when fetching height of the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZBDAO0003"
    case blockDAOLatestBlockHeight(_ sqliteError: Error)
    /// SQLite query failed when fetching the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZBDAO0004"
    case blockDAOLatestBlock(_ sqliteError: Error)
    /// Fetched latesxt block information from DB but can't decode them.
    /// - `error` is decoding error.
    // sourcery: code="ZBDAO0005"
    case blockDAOLatestBlockCantDecode(_ error: Error)

    // MARK: - Rust

    /// Error from rust layer when calling ZcashRustBackend.createAccount
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0001"
    case rustCreateAccount(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.createToAddress
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0002"
    case rustCreateToAddress(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.decryptAndStoreTransaction
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0003"
    case rustDecryptAndStoreTransaction(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getBalance
    /// - `account` is account passed to ZcashRustBackend.getBalance.
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0004"
    case rustGetBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getCurrentAddress
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0005"
    case rustGetCurrentAddress(_ rustError: String)
    /// Unified address generated by rust layer is invalid when calling ZcashRustBackend.getCurrentAddress
    // sourcery: code="ZRUST0006"
    case rustGetCurrentAddressInvalidAddress
    /// Error from rust layer when calling ZcashRustBackend.getNearestRewindHeight
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0007"
    case rustGetNearestRewindHeight(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getNextAvailableAddress
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0008"
    case rustGetNextAvailableAddress(_ rustError: String)
    /// Unified address generated by rust layer is invalid when calling ZcashRustBackend.getNextAvailableAddress
    // sourcery: code="ZRUST0009"
    case rustGetNextAvailableAddressInvalidAddress
    /// account parameter is lower than 0 when calling ZcashRustBackend.getTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getTransparentBalance.
    // sourcery: code="ZRUST0010"
    case rustGetTransparentBalanceNegativeAccount(_ account: Int)
    /// Error from rust layer when calling ZcashRustBackend.getTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getTransparentBalance.
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0011"
    case rustGetTransparentBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getVerifiedBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedBalance.
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0012"
    case rustGetVerifiedBalance(_ account: Int, _ rustError: String)
    /// account parameter is lower than 0 when calling ZcashRustBackend.getVerifiedTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedTransparentBalance.
    // sourcery: code="ZRUST0013"
    case rustGetVerifiedTransparentBalanceNegativeAccount(_ account: Int)
    /// Error from rust layer when calling ZcashRustBackend.getVerifiedTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedTransparentBalance.
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0014"
    case rustGetVerifiedTransparentBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.initDataDb
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0015"
    case rustInitDataDb(_ rustError: String)
    /// Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method contains null bytes before end
    // sourcery: code="ZRUST0016"
    case rustInitAccountsTableViewingKeyCotainsNullBytes
    /// Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method isn't valid
    // sourcery: code="ZRUST0017"
    case rustInitAccountsTableViewingKeyIsInvalid
    /// Error from rust layer when calling ZcashRustBackend.initAccountsTable
    // sourcery: code="ZRUST0018"
    case rustInitAccountsTableDataDbNotEmpty
    /// Error from rust layer when calling ZcashRustBackend.initAccountsTable
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0019"
    case rustInitAccountsTable(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.initBlockMetadataDb
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0020"
    case rustInitBlockMetadataDb(_ rustError: String)
    /// Unable to allocate memory required to write blocks when calling ZcashRustBackend.writeBlocksMetadata
    // sourcery: code="ZRUST0021"
    case rustWriteBlocksMetadataAllocationProblem
    /// Error from rust layer when calling ZcashRustBackend.writeBlocksMetadata
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0022"
    case rustWriteBlocksMetadata(_ rustError: String)
    /// hash passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end
    // sourcery: code="ZRUST0023"
    case rustInitBlocksTableHashContainsNullBytes
    /// saplingTree passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end
    // sourcery: code="ZRUST0024"
    case rustInitBlocksTableSaplingTreeContainsNullBytes
    /// Error from rust layer when calling ZcashRustBackend.initBlocksTable
    // sourcery: code="ZRUST0025"
    case rustInitBlocksTableDataDbNotEmpty
    /// Error from rust layer when calling ZcashRustBackend.initBlocksTable
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0026"
    case rustInitBlocksTable(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.listTransparentReceivers
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0027"
    case rustListTransparentReceivers(_ rustError: String)
    /// Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.listTransparentReceivers
    // sourcery: code="ZRUST0028"
    case rustListTransparentReceiversInvalidAddress
    /// Error from rust layer when calling ZcashRustBackend.putUnspentTransparentOutput
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0029"
    case rustPutUnspentTransparentOutput(_ rustError: String)
    /// Error unrelated to chain validity from rust layer when calling ZcashRustBackend.validateCombinedChain
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0030"
    case rustValidateCombinedChainValidationFailed(_ rustError: String)
    /// Error from rust layer which means that combined chain isn't valid.
    /// - `upperBound` is the height of the highest invalid block (on the assumption that the highest block in the cache database is correct).
    // sourcery: code="ZRUST0031"
    case rustValidateCombinedChainInvalidChain(_ upperBound: Int32)
    /// Error from rust layer when calling ZcashRustBackend.rewindToHeight
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0032"
    case rustRewindToHeight(_ height: Int32, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.rewindCacheToHeight
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0033"
    case rustRewindCacheToHeight(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.scanBlocks
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0034"
    case rustScanBlocks(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.shieldFunds
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0035"
    case rustShieldFunds(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.consensusBranchIdFor
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0036"
    case rustNoConsensusBranchId(_ height: Int32)
    /// address passed to the ZcashRustBackend.receiverTypecodesOnUnifiedAddress method contains null bytes before end
    /// - `address` is address passed to ZcashRustBackend.receiverTypecodesOnUnifiedAddress.
    // sourcery: code="ZRUST0037"
    case rustReceiverTypecodesOnUnifiedAddressContainsNullBytes(_ address: String)
    /// Error from rust layer when calling ZcashRustBackend.receiverTypecodesOnUnifiedAddress
    // sourcery: code="ZRUST0038"
    case rustRustReceiverTypecodesOnUnifiedAddressMalformed
    /// Error from rust layer when calling ZcashRustBackend.deriveUnifiedSpendingKey
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0039"
    case rustDeriveUnifiedSpendingKey(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.deriveUnifiedFullViewingKey
    /// - `rustError` contains error generated by the rust layer.
    // sourcery: code="ZRUST0040"
    case rustDeriveUnifiedFullViewingKey(_ rustError: String)
    /// Viewing key derived by rust layer is invalid when calling ZcashRustBackend.deriveUnifiedFullViewingKey
    // sourcery: code="ZRUST0041"
    case rustDeriveUnifiedFullViewingKeyInvalidDerivedKey
    /// Error from rust layer when calling ZcashRustBackend.getSaplingReceiver
    /// - `address` is address passed to ZcashRustBackend.getSaplingReceiver.
    // sourcery: code="ZRUST0042"
    case rustGetSaplingReceiverInvalidAddress(_ address: UnifiedAddress)
    /// Sapling receiver generated by rust layer is invalid when calling ZcashRustBackend.getSaplingReceiver
    // sourcery: code="ZRUST0043"
    case rustGetSaplingReceiverInvalidReceiver
    /// Error from rust layer when calling ZcashRustBackend.getTransparentReceiver
    /// - `address` is address passed to ZcashRustBackend.getTransparentReceiver.
    // sourcery: code="ZRUST0044"
    case rustGetTransparentReceiverInvalidAddress(_ address: UnifiedAddress)
    /// Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.getTransparentReceiver
    // sourcery: code="ZRUST0045"
    case rustGetTransparentReceiverInvalidReceiver

    // MARK: - Account DAO

    /// SQLite query failed when fetching all accounts from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZADAO0001"
    case accountDAOGetAll(_ sqliteError: Error)
    /// Fetched accounts from SQLite but can't decode them.
    /// - `error` is decoding error.
    // sourcery: code="ZADAO0002"
    case accountDAOGetAllCantDecode(_ error: Error)
    /// SQLite query failed when seaching for accounts in the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZADAO0003"
    case accountDAOFindBy(_ sqliteError: Error)
    /// Fetched accounts from SQLite but can't decode them.
    /// - `error` is decoding error.
    // sourcery: code="ZADAO0004"
    case accountDAOFindByCantDecode(_ error: Error)
    /// Object passed to update() method conforms to `AccountEntity` protocol but isn't exactly `Account` type.
    // sourcery: code="ZADAO0005"
    case accountDAOUpdateInvalidAccount
    /// SQLite query failed when updating account in the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZADAO0006"
    case accountDAOUpdate(_ sqliteError: Error)
    /// Update of the account updated 0 rows in the database. One row should be updated.
    // sourcery: code="ZADAO0007"
    case accountDAOUpdatedZeroRows

    // MARK: - Block storage

    /// Failed to write block to disk.
    // sourcery: code="ZBLRP00001"
    case blockRepositoryWriteBlock(_ block: ZcashCompactBlock, _ error: Error)
    /// Failed to get filename for the block from file URL.
    // sourcery: code="ZBLRP0002"
    case blockRepositoryGetFilename(_ url: URL)
    /// Failed to parse block height from filename.
    // sourcery: code="ZBLRP0003"
    case blockRepositoryParseHeightFromFilename(_ filename: String)
    /// Failed to remove existing block from disk.
    // sourcery: code="ZBLRP0004"
    case blockRepositoryRemoveExistingBlock(_ url: URL, _ error: Error)
    /// Failed to get filename and information if url points to directory from file URL.
    // sourcery: code="ZBLRP0005"
    case blockRepositoryGetFilenameAndIsDirectory(_ url: URL)
    /// Failed to create blocks cache directory.
    // sourcery: code="ZBLRP0006"
    case blockRepositoryCreateBlocksCacheDirectory(_ url: URL, _ error: Error)
    /// Failed to read content of directory.
    // sourcery: code="ZBLRP0007"
    case blockRepositoryReadDirectoryContent(_ url: URL, _ error: Error)
    /// Failed to remove block from disk after rewind operation.
    // sourcery: code="ZBLRP0008"
    case blockRepositoryRemoveBlockAfterRewind(_ url: URL, _ error: Error)
    /// Failed to remove blocks cache directory while clearing storage.
    // sourcery: code="ZBLRP0009"
    case blockRepositoryRemoveBlocksCacheDirectory(_ url: URL, _ error: Error)
    /// Failed to remove block from cache when clearing cache up to some height.
    // sourcery: code="ZBLRP0010"
    case blockRepositoryRemoveBlockClearingCache(_ url: URL, _ error: Error)

    // MARK: - Block Download

    /// Trying to download blocks before sync range is set in `BlockDownloaderImpl`. This means that download stream is not created and download cant' start.
    // sourcery: code="ZBDWN0001"
    case blockDownloadSyncRangeNotSet
    
    // MARK: - BlockDownloaderService

    /// Stream downloading the given block range failed.
    // sourcery: code="ZBDSEO0001"
    case blockDownloaderServiceDownloadBlockRange(_ error: Error)

    // MARK: - Transaction Entity / ZcashTransaction

    /// Initialization of `ZcashTransaction.Overview` failed.
    // sourcery: code="ZTEZT0001"
    case zcashTransactionOverviewInit(_ error: Error)
    /// Initialization of `ZcashTransaction.Received` failed.
    // sourcery: code="ZTEZT0002"
    case zcashTransactionReceivedInit(_ error: Error)
    /// Initialization of `ZcashTransaction.Sent` failed.
    // sourcery: code="ZTEZT0003"
    case zcashTransactionSentInit(_ error: Error)
    /// Initialization of `ZcashTransaction.Output` failed.
    // sourcery: code="ZTEZT0004"
    case zcashTransactionOutputInit(_ error: Error)

    /// Initialization of `ZcashTransaction.Output` failed because there an inconsistency in the output recipient.
    // sourcery: code="ZTEZT0005"
    case zcashTransactionOutputInconsistentRecipient

    // MARK: - Transaction Repository
    
    /// Entity not found in the database, result of `createEntity` execution.
    // sourcery: code="ZTREE0001"
    case transactionRepositoryEntityNotFound
    /// `Find` call is missing fields, required fields are transaction `index` and `blockTime`.
    // sourcery: code="ZTREE0002"
    case transactionRepositoryTransactionMissingRequiredFields
    /// Counting all transactions failed.
    // sourcery: code="ZTREE0003"
    case transactionRepositoryCountAll(_ error: Error)
    /// Counting all unmined transactions failed.
    // sourcery: code="ZTREE0004"
    case transactionRepositoryCountUnmined(_ error: Error)
    /// Execution of a query failed.
    // sourcery: code="ZTREE0005"
    case transactionRepositoryQueryExecute(_ error: Error)
    /// Finding memos in the database failed.
    // sourcery: code="ZTREE0006"
    case transactionRepositoryFindMemos(_ error: Error)

    // MARK: - ZcashCompactBlock

    /// Can't encode `ZcashCompactBlock` object.
    // sourcery: code="ZCMPB0001"
    case compactBlockEncode(_ error: Error)

    // MARK: - Memo

    /// Invalid UTF-8 Bytes where detected when attempting to create a MemoText.
    // sourcery: code="ZMEMO0001"
    case memoTextInvalidUTF8
    /// Trailing null-bytes were found when attempting to create a MemoText.
    // sourcery: code="ZMEMO0002"
    case memoTextInputEndsWithNullBytes
    /// The resulting bytes provided are too long to be stored as a MemoText.
    // sourcery: code="ZMEMO0003"
    case memoTextInputTooLong(_ length: Int)
    /// The resulting bytes provided are too long to be stored as a MemoBytes.
    // sourcery: code="ZMEMO0004"
    case memoBytesInputTooLong(_ length: Int)
    /// Invalid UTF-8 Bytes where detected when attempting to convert MemoBytes to Memo.
    // sourcery: code="ZMEMO0005"
    case memoBytesInvalidUTF8

    // MARK: - Checkpoint

    /// Failed to load JSON with checkpoint from disk.
    // sourcery: code="ZCHKP0001"
    case checkpointCantLoadFromDisk(_ error: Error)
    /// Failed to decode `Checkpoint` object.
    // sourcery: code="ZCHKP0002"
    case checkpointDecode(_ error: Error)

    // MARK: - DerivationTool

    /// Invalid account when trying to derive spending key
    // sourcery: code="ZDRVT0001"
    case derivationToolSpendingKeyInvalidAccount

    // MARK: - UnspentTransactionOutputDAO

    /// Creation of the table for unspent transaction output failed.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZUTOD0001"
    case unspentTransactionOutputDAOCreateTable(_ sqliteError: Error)
    /// SQLite query failed when storing unspent transaction output.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZUTOD0002"
    case unspentTransactionOutputDAOStore(_ sqliteError: Error)
    /// SQLite query failed when removing all the unspent transation outputs.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZUTOD0003"
    case unspentTransactionOutputDAOClearAll(_ sqliteError: Error)
    /// Fetched information about unspent transaction output from the DB but it can't be decoded to `UTXO` object.
    /// - `error` decoding error.
    // sourcery: code="ZUTOD0004"
    case unspentTransactionOutputDAOGetAllCantDecode(_ error: Error)
    /// SQLite query failed when getting all the unspent transation outputs.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZUTOD0005"
    case unspentTransactionOutputDAOGetAll(_ sqliteError: Error)
    /// SQLite query failed when getting balance.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZUTOD0006"
    case unspentTransactionOutputDAOBalance(_ sqliteError: Error)

    // MARK: - WalletTypes

    /// Can't create `SaplingExtendedSpendingKey` because input is invalid.
    // sourcery: code="ZWLTP0001"
    case spendingKeyInvalidInput
    /// Can't create `UnifiedFullViewingKey` because input is invalid.
    // sourcery: code="ZWLTP0002"
    case unifiedFullViewingKeyInvalidInput
    /// Can't create `SaplingExtendedFullViewingKey` because input is invalid.
    // sourcery: code="ZWLTP0003"
    case extetendedFullViewingKeyInvalidInput
    /// Can't create `TransparentAddress` because input is invalid.
    // sourcery: code="ZWLTP0004"
    case transparentAddressInvalidInput
    /// Can't create `SaplingAddress` because input is invalid.
    // sourcery: code="ZWLTP0005"
    case saplingAddressInvalidInput
    /// Can't create `UnifiedAddress` because input is invalid.
    // sourcery: code="ZWLTP0006"
    case unifiedAddressInvalidInput
    /// Can't create `Recipient` because input is invalid.
    // sourcery: code="ZWLTP0007"
    case recipientInvalidInput

    // MARK: - WalletTransactionEncoder

    /// WalletTransactionEncoder wants to create transaction but files with sapling parameters are not present on disk.
    // sourcery: code="ZWLTE0001"
    case walletTransEncoderCreateTransactionMissingSaplingParams
    /// WalletTransactionEncoder wants to shield funds but files with sapling parameters are not present on disk.
    // sourcery: code="ZWLTE0002"
    case walletTransEncoderShieldFundsMissingSaplingParams
    
    // MARK: - Zatoshi
    
    /// Initiatilzation fo `Zatoshi` from a decoder failed.
    // sourcery: code="ZTSHO0001"
    case zatoshiDecode(_ error: Error)
    /// Encode of `Zatoshi` failed.
    // sourcery: code="ZTSHO0002"
    case zatoshiEncode(_ error: Error)

    // MARK: - UTXOFetcher
    
    /// Awaiting transactions from the stream failed.
    // sourcery: code="ZUTXO0001"
    case unspentTransactionFetcherStream(_ error: Error)

    // MARK: - CompactBlockProcessor

    /// CompactBlockProcessor was started with an invalid configuration.
    // sourcery: code="ZCBPEO0001"
    case compactBlockProcessorInvalidConfiguration
    /// CompactBlockProcessor was set up with path but that location couldn't be reached.
    // sourcery: code="ZCBPEO0002"
    case compactBlockProcessorMissingDbPath(_ path: String)
    /// Data Db file couldn't be initialized at path.
    // sourcery: code="ZCBPEO0003"
    case compactBlockProcessorDataDbInitFailed(_ path: String)
    /// There's a problem with the network connection.
    // sourcery: code="ZCBPEO0004"
    case compactBlockProcessorConnection(_ underlyingError: Error)
    /// Error on gRPC happened.
    // sourcery: code="ZCBPEO0005"
    case compactBlockProcessorGrpcError(statusCode: Int, message: String)
    /// Network connection timeout.
    // sourcery: code="ZCBPEO0006"
    case compactBlockProcessorConnectionTimeout
    /// Compact Block failed and reached the maximum amount of retries it was set up to do.
    // sourcery: code="ZCBPEO0007"
    case compactBlockProcessorMaxAttemptsReached(_ attempts: Int)
    /// Unspecified error occured.
    // sourcery: code="ZCBPEO0008"
    case compactBlockProcessorUnspecified(_ underlyingError: Error)
    /// Critical error occured.
    // sourcery: code="ZCBPEO0009"
    case compactBlockProcessorCritical
    /// Invalid Account.
    // sourcery: code="ZCBPEO0010"
    case compactBlockProcessorInvalidAccount
    /// The remote server you are connecting to is publishing a different branch ID than the one your App is expecting This could be caused by your App being out of date or the server you are connecting you being either on a different network or out of date after a network upgrade.
    // sourcery: code="ZCBPEO0011"
    case compactBlockProcessorWrongConsensusBranchId(expectedLocally: ConsensusBranchID, found: ConsensusBranchID)
    /// A server was reached, but it's targeting the wrong network Type. Make sure you are pointing to the right server.
    // sourcery: code="ZCBPEO0012"
    case compactBlockProcessorNetworkMismatch(expected: NetworkType, found: NetworkType)
    /// A server was reached, it's showing a different sapling activation. Are you sure you are pointing to the right server?
    // sourcery: code="ZCBPEO0013"
    case compactBlockProcessorSaplingActivationMismatch(expected: BlockHeight, found: BlockHeight)
    /// when the given URL is the same URL than the one provided as `self.fsBlockDbRoot` assuming that's a programming error being the `legacyCacheDbURL` a sqlite database file and not a directory
    // sourcery: code="ZCBPEO0014"
    case compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL
    /// Deletion of readable file at the provided URL failed.
    // sourcery: code="ZCBPEO0015"
    case compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb(_ error: Error)
    /// Chain name does not match. Expected either 'test' or 'main'. This is probably an API or programming error.
    // sourcery: code="ZCBPEO0016"
    case compactBlockProcessorChainName(_ name: String)
    /// Consensus BranchIDs don't match this is probably an API or programming error.
    // sourcery: code="ZCBPEO0017"
    case compactBlockProcessorConsensusBranchID
    
    // MARK: - SDKSynchronizer
    
    /// The synchronizer is unprepared.
    // sourcery: code="ZSYNCO0001"
    case synchronizerNotPrepared
    /// Memos can't be sent to transparent addresses.
    // sourcery: code="ZSYNCO0002"
    case synchronizerSendMemoToTransparentAddress
    /// There is not enough transparent funds to cover fee for the shielding.
    // sourcery: code="ZSYNCO0003"
    case synchronizerShieldFundsInsuficientTransparentFunds
    /// LatestUTXOs for the address failed, invalid t-address.
    // sourcery: code="ZSYNCO0004"
    case synchronizerLatestUTXOsInvalidTAddress
    /// Rewind failed, unknown archor height
    // sourcery: code="ZSYNCO0005"
    case synchronizerRewindUnknownArchorHeight
    /// Indicates that this Synchronizer is disconnected from its lightwalletd server.
    // sourcery: code="ZSYNCO0006"
    case synchronizerDisconnected
}
