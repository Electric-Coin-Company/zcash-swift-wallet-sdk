// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

/*
!!!!! To edit this file go to ZcashErrorCodeDefinition first and udate/add codes. Then run generateErrorCode.sh script to regenerate this file.

By design each error should be used only at one place in the app. Thanks to that it is possible to identify exact line in the code from which the
error originates. And it can help with debugging.
*/

import Foundation

public enum ZcashError: Equatable, Error {
    /// Updating of paths in `Initilizer` according to alias failed.
    /// ZINIT0001
    case initializerCantUpdateURLWithAlias(_ url: URL)
    /// Alias used to create this instance of the `SDKSynchronizer` is already used by other instance.
    /// ZINIT0002
    case initializerAliasAlreadyInUse(_ alias: ZcashSynchronizerAlias)
    /// Unknown GRPC Service error
    /// ZSRVC0001
    case serviceUnknownError(_ error: Error)
    /// LightWalletService.getInfo failed.
    /// ZSRVC0002
    case serviceGetInfoFailed(_ error: LightWalletServiceError)
    /// LightWalletService.latestBlock failed.
    /// ZSRVC0003
    case serviceLatestBlockFailed(_ error: LightWalletServiceError)
    /// LightWalletService.latestBlockHeight failed.
    /// ZSRVC0004
    case serviceLatestBlockHeightFailed(_ error: LightWalletServiceError)
    /// LightWalletService.blockRange failed.
    /// ZSRVC0005
    case serviceBlockRangeFailed(_ error: LightWalletServiceError)
    /// LightWalletService.submit failed.
    /// ZSRVC0006
    case serviceSubmitFailed(_ error: LightWalletServiceError)
    /// LightWalletService.fetchTransaction failed.
    /// ZSRVC0007
    case serviceFetchTransactionFailed(_ error: LightWalletServiceError)
    /// LightWalletService.fetchUTXOs failed.
    /// ZSRVC0008
    case serviceFetchUTXOsFailed(_ error: LightWalletServiceError)
    /// LightWalletService.blockStream failed.
    /// ZSRVC0000
    case serviceBlockStreamFailed(_ error: LightWalletServiceError)
    /// Migration of the pending DB failed because of unspecific reason.
    /// ZDBMG0001
    case dbMigrationGenericFailure(_ error: Error)
    /// Migration of the pending DB failed because unknown version of the existing database.
    /// ZDBMG00002
    case dbMigrationInvalidVersion
    /// Migration of the pending DB to version 1 failed.
    /// ZDBMG00003
    case dbMigrationV1(_ dbError: Error)
    /// Migration of the pending DB to version 2 failed.
    /// ZDBMG00004
    case dbMigrationV2(_ dbError: Error)
    /// SimpleConnectionProvider init of Connection failed.
    /// ZSCPC0001
    case simpleConnectionProvider(_ error: Error)
    /// Downloaded file with sapling spending parameters isn't valid.
    /// ZSAPP0001
    case saplingParamsInvalidSpendParams
    /// Downloaded file with sapling output parameters isn't valid.
    /// ZSAPP0002
    case saplingParamsInvalidOutputParams
    /// Failed to download sapling parameters file
    /// - `error` is download error.
    /// - `downloadURL` is URL from which was file downloaded.
    /// ZSAPP0003
    case saplingParamsDownload(_ error: Error, _ downloadURL: URL)
    /// Failed to move sapling parameters file to final destination after download.
    /// - `error` is move error.
    /// - `downloadURL` is URL from which was file downloaded.
    /// - `destination` is filesystem URL pointing to location where downloaded file should be moved.
    /// ZSAPP0004
    case saplingParamsCantMoveDownloadedFile(_ error: Error, _ downloadURL: URL, _ destination: URL)
    /// SQLite query failed when fetching received notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZNDAO0001
    case notesDAOReceivedCount(_ sqliteError: Error)
    /// SQLite query failed when fetching received notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZNDAO0002
    case notesDAOReceivedNote(_ sqliteError: Error)
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    /// ZNDAO0003
    case notesDAOReceivedCantDecode(_ error: Error)
    /// SQLite query failed when fetching sent notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZNDAO0004
    case notesDAOSentCount(_ sqliteError: Error)
    /// SQLite query failed when fetching sent notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZNDAO0005
    case notesDAOSentNote(_ sqliteError: Error)
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    /// ZNDAO0006
    case notesDAOSentCantDecode(_ error: Error)
    /// SQLite query failed when fetching block information from database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZBDAO0001
    case blockDAOBlock(_ sqliteError: Error)
    /// Fetched block information from DB but can't decode them.
    /// - `error` is decoding error.
    /// ZBDAO0002
    case blockDAOCantDecode(_ error: Error)
    /// SQLite query failed when fetching height of the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZBDAO0003
    case blockDAOLatestBlockHeight(_ sqliteError: Error)
    /// SQLite query failed when fetching the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZBDAO0004
    case blockDAOLatestBlock(_ sqliteError: Error)
    /// Fetched latesxt block information from DB but can't decode them.
    /// - `error` is decoding error.
    /// ZBDAO0005
    case blockDAOLatestBlockCantDecode(_ error: Error)
    /// Error from rust layer when calling ZcashRustBackend.createAccount
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0001
    case rustCreateAccount(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.createToAddress
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0002
    case rustCreateToAddress(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.decryptAndStoreTransaction
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0003
    case rustDecryptAndStoreTransaction(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getBalance
    /// - `account` is account passed to ZcashRustBackend.getBalance.
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0004
    case rustGetBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getCurrentAddress
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0005
    case rustGetCurrentAddress(_ rustError: String)
    /// Unified address generated by rust layer is invalid when calling ZcashRustBackend.getCurrentAddress
    /// ZRUST0006
    case rustGetCurrentAddressInvalidAddress
    /// Error from rust layer when calling ZcashRustBackend.getNearestRewindHeight
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0007
    case rustGetNearestRewindHeight(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getNextAvailableAddress
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0008
    case rustGetNextAvailableAddress(_ rustError: String)
    /// Unified address generated by rust layer is invalid when calling ZcashRustBackend.getNextAvailableAddress
    /// ZRUST0009
    case rustGetNextAvailableAddressInvalidAddress
    /// account parameter is lower than 0 when calling ZcashRustBackend.getTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getTransparentBalance.
    /// ZRUST0010
    case rustGetTransparentBalanceNegativeAccount(_ account: Int)
    /// Error from rust layer when calling ZcashRustBackend.getTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getTransparentBalance.
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0011
    case rustGetTransparentBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.getVerifiedBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedBalance.
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0012
    case rustGetVerifiedBalance(_ account: Int, _ rustError: String)
    /// account parameter is lower than 0 when calling ZcashRustBackend.getVerifiedTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedTransparentBalance.
    /// ZRUST0013
    case rustGetVerifiedTransparentBalanceNegativeAccount(_ account: Int)
    /// Error from rust layer when calling ZcashRustBackend.getVerifiedTransparentBalance
    /// - `account` is account passed to ZcashRustBackend.getVerifiedTransparentBalance.
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0014
    case rustGetVerifiedTransparentBalance(_ account: Int, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.initDataDb
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0015
    case rustInitDataDb(_ rustError: String)
    /// Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method contains null bytes before end
    /// ZRUST0016
    case rustInitAccountsTableViewingKeyCotainsNullBytes
    /// Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method isn't valid
    /// ZRUST0017
    case rustInitAccountsTableViewingKeyIsInvalid
    /// Error from rust layer when calling ZcashRustBackend.initAccountsTable
    /// ZRUST0018
    case rustInitAccountsTableDataDbNotEmpty
    /// Error from rust layer when calling ZcashRustBackend.initAccountsTable
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0019
    case rustInitAccountsTable(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.initBlockMetadataDb
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0020
    case rustInitBlockMetadataDb(_ rustError: String)
    /// Unable to allocate memory required to write blocks when calling ZcashRustBackend.writeBlocksMetadata
    /// ZRUST0021
    case rustWriteBlocksMetadataAllocationProblem
    /// Error from rust layer when calling ZcashRustBackend.writeBlocksMetadata
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0022
    case rustWriteBlocksMetadata(_ rustError: String)
    /// hash passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end
    /// ZRUST0023
    case rustInitBlocksTableHashContainsNullBytes
    /// saplingTree passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end
    /// ZRUST0024
    case rustInitBlocksTableSaplingTreeContainsNullBytes
    /// Error from rust layer when calling ZcashRustBackend.initBlocksTable
    /// ZRUST0025
    case rustInitBlocksTableDataDbNotEmpty
    /// Error from rust layer when calling ZcashRustBackend.initBlocksTable
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0026
    case rustInitBlocksTable(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.listTransparentReceivers
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0027
    case rustListTransparentReceivers(_ rustError: String)
    /// Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.listTransparentReceivers
    /// ZRUST0028
    case rustListTransparentReceiversInvalidAddress
    /// Error from rust layer when calling ZcashRustBackend.putUnspentTransparentOutput
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0029
    case rustPutUnspentTransparentOutput(_ rustError: String)
    /// Error unrelated to chain validity from rust layer when calling ZcashRustBackend.validateCombinedChain
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0030
    case rustValidateCombinedChainValidationFailed(_ rustError: String)
    /// Error from rust layer which means that combined chain isn't valid.
    /// - `upperBound` is the height of the highest invalid block (on the assumption that the highest block in the cache database is correct).
    /// ZRUST0031
    case rustValidateCombinedChainInvalidChain(_ upperBound: Int32)
    /// Error from rust layer when calling ZcashRustBackend.rewindToHeight
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0032
    case rustRewindToHeight(_ height: Int32, _ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.rewindCacheToHeight
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0033
    case rustRewindCacheToHeight(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.scanBlocks
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0034
    case rustScanBlocks(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.shieldFunds
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0035
    case rustShieldFunds(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.consensusBranchIdFor
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0036
    case rustNoConsensusBranchId(_ height: Int32)
    /// address passed to the ZcashRustBackend.receiverTypecodesOnUnifiedAddress method contains null bytes before end
    /// - `address` is address passed to ZcashRustBackend.receiverTypecodesOnUnifiedAddress.
    /// ZRUST0037
    case rustReceiverTypecodesOnUnifiedAddressContainsNullBytes(_ address: String)
    /// Error from rust layer when calling ZcashRustBackend.receiverTypecodesOnUnifiedAddress
    /// ZRUST0038
    case rustRustReceiverTypecodesOnUnifiedAddressMalformed
    /// Error from rust layer when calling ZcashRustBackend.deriveUnifiedSpendingKey
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0039
    case rustDeriveUnifiedSpendingKey(_ rustError: String)
    /// Error from rust layer when calling ZcashRustBackend.deriveUnifiedFullViewingKey
    /// - `rustError` contains error generated by the rust layer.
    /// ZRUST0040
    case rustDeriveUnifiedFullViewingKey(_ rustError: String)
    /// Viewing key derived by rust layer is invalid when calling ZcashRustBackend.deriveUnifiedFullViewingKey
    /// ZRUST0041
    case rustDeriveUnifiedFullViewingKeyInvalidDerivedKey
    /// Error from rust layer when calling ZcashRustBackend.getSaplingReceiver
    /// - `address` is address passed to ZcashRustBackend.getSaplingReceiver.
    /// ZRUST0042
    case rustGetSaplingReceiverInvalidAddress(_ address: UnifiedAddress)
    /// Sapling receiver generated by rust layer is invalid when calling ZcashRustBackend.getSaplingReceiver
    /// ZRUST0043
    case rustGetSaplingReceiverInvalidReceiver
    /// Error from rust layer when calling ZcashRustBackend.getTransparentReceiver
    /// - `address` is address passed to ZcashRustBackend.getTransparentReceiver.
    /// ZRUST0044
    case rustGetTransparentReceiverInvalidAddress(_ address: UnifiedAddress)
    /// Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.getTransparentReceiver
    /// ZRUST0045
    case rustGetTransparentReceiverInvalidReceiver
    /// SQLite query failed when fetching all accounts from the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZADAO0001
    case accountDAOGetAll(_ sqliteError: Error)
    /// Fetched accounts from SQLite but can't decode them.
    /// - `error` is decoding error.
    /// ZADAO0002
    case accountDAOGetAllCantDecode(_ error: Error)
    /// SQLite query failed when seaching for accounts in the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZADAO0003
    case accountDAOFindBy(_ sqliteError: Error)
    /// Fetched accounts from SQLite but can't decode them.
    /// - `error` is decoding error.
    /// ZADAO0004
    case accountDAOFindByCantDecode(_ error: Error)
    /// Object passed to update() method conforms to `AccountEntity` protocol but isn't exactly `Account` type.
    /// ZADAO0005
    case accountDAOUpdateInvalidAccount
    /// SQLite query failed when updating account in the database.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZADAO0006
    case accountDAOUpdate(_ sqliteError: Error)
    /// Update of the account updated 0 rows in the database. One row should be updated.
    /// ZADAO0007
    case accountDAOUpdatedZeroRows
    /// Failed to write block to disk.
    /// ZBLRP00001
    case blockRepositoryWriteBlock(_ block: ZcashCompactBlock)
    /// Failed to get filename for the block from file URL.
    /// ZBLRP0002
    case blockRepositoryGetFilename(_ url: URL)
    /// Failed to parse block height from filename.
    /// ZBLRP0003
    case blockRepositoryParseHeightFromFilename(_ filename: String)
    /// Failed to remove existing block from disk.
    /// ZBLRP0004
    case blockRepositoryRemoveExistingBlock(_ error: Error)
    /// Failed to get filename and information if url points to directory from file URL.
    /// ZBLRP0005
    case blockRepositoryGetFilenameAndIsDirectory(_ url: URL)
    /// Failed to create blocks cache directory.
    /// ZBLRP0006
    case blockRepositoryCreateBlocksCacheDirectory(_ url: URL)
    /// Failed to read content of directory.
    /// ZBLRP0007
    case blockRepositoryReadDirectoryContent(_ url: URL)
    /// Failed to remove block from disk after rewind operation.
    /// ZBLRP0008
    case blockRepositoryRemoveBlockAfterRewind(_ url: URL)
    /// Failed to remove blocks cache directory while clearing storage.
    /// ZBLRP0009
    case blockRepositoryRemoveBlocksCacheDirectory(_ url: URL)
    /// Stream downloading the given block range failed.
    /// ZBDSEO0001
    case blockDownloaderServiceDownloadBlockRange(_ error: Error)
    /// Initialization of `ZcashTransaction.Overview` failed.
    /// ZTEZT0001
    case zcashTransactionOverviewInit(_ error: Error)
    /// Initialization of `ZcashTransaction.Received` failed.
    /// ZTEZT0002
    case zcashTransactionReceivedInit(_ error: Error)
    /// Initialization of `ZcashTransaction.Sent` failed.
    /// ZTEZT0003
    case zcashTransactionSentInit(_ error: Error)
    /// Entity not found in the database, result of `createEntity` execution.
    /// ZTREE0001
    case transactionRepositoryEntityNotFound
    /// `Find` call is missing fields, required fields are transaction `index` and `blockTime`.
    /// ZTREE0002
    case transactionRepositoryTransactionMissingRequiredFields
    /// Counting all transactions failed.
    /// ZTREE0003
    case transactionRepositoryCountAll(_ error: Error)
    /// Counting all unmined transactions failed.
    /// ZTREE0004
    case transactionRepositoryCountUnmined(_ error: Error)
    /// Execution of a query failed.
    /// ZTREE0005
    case transactionRepositoryQueryExecute(_ error: Error)
    /// Finding memos in the database failed.
    /// ZTREE0006
    case transactionRepositoryFindMemos(_ error: Error)
    /// Can't encode `ZcashCompactBlock` object.
    /// ZCMPB0001
    case compactBlockEncode(_ error: Error)
    /// Invalid UTF-8 Bytes where detected when attempting to create a MemoText.
    /// ZMEMO0001
    case memoTextInvalidUTF8
    /// Trailing null-bytes were found when attempting to create a MemoText.
    /// ZMEMO0002
    case memoTextInputEndsWithNullBytes
    /// The resulting bytes provided are too long to be stored as a MemoText.
    /// ZMEMO0003
    case memoTextInputTooLong(_ length: Int)
    /// The resulting bytes provided are too long to be stored as a MemoBytes.
    /// ZMEMO0004
    case memoBytesInputTooLong(_ length: Int)
    /// Invalid UTF-8 Bytes where detected when attempting to convert MemoBytes to Memo.
    /// ZMEMO0005
    case memoBytesInvalidUTF8
    /// Failed to load JSON with checkpoint from disk.
    /// ZCHKP0001
    case checkpointCantLoadFromDisk(_ error: Error)
    /// Failed to decode `Checkpoint` object.
    /// ZCHKP0002
    case checkpointDecode(_ error: Error)
    /// Decoding of `PendingTransaction` failed because of specific invalid data.
    /// - `field` is list of fields names that contain invalid data.
    /// ZPETR0001
    case pendingTransactionDecodeInvalidData(_ fields: [String])
    /// Can't decode `PendingTransaction`.
    /// - `error` is error which described why decoding failed.
    /// ZPETR0002
    case pendingTransactionCantDecode(_ error: Error)
    /// Can't encode `PendingTransaction`.
    /// - `error` is error which described why encoding failed.
    /// ZPETR0003
    case pendingTransactionCantEncode(_ error: Error)
    /// SQLite query failed when creating pending transaction.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0004
    case pendingTransactionDAOCreate(_ sqliteError: Error)
    /// Pending transaction which should be updated is missing ID.
    /// ZPETR0005
    case pendingTransactionDAOUpdateMissingID
    /// SQLite query failed when updating pending transaction.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0006
    case pendingTransactionDAOUpdate(_ sqliteError: Error)
    /// Pending transaction which should be deleted is missing ID.
    /// ZPETR0007
    case pendingTransactionDAODeleteMissingID
    /// SQLite query failed when deleting pending transaction.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0008
    case pendingTransactionDAODelete(_ sqliteError: Error)
    /// Pending transaction which should be canceled is missing ID.
    /// ZPETR0009
    case pendingTransactionDAOCancelMissingID
    /// SQLite query failed when canceling pending transaction.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0010
    case pendingTransactionDAOCancel(_ sqliteError: Error)
    /// SQLite query failed when seaching for pending transaction.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0011
    case pendingTransactionDAOFind(_ sqliteError: Error)
    /// SQLite query failed when getting pending transactions.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0012
    case pendingTransactionDAOGetAll(_ sqliteError: Error)
    /// SQLite query failed when applying mined height.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZPETR0013
    case pendingTransactionDAOApplyMinedHeight(_ sqliteError: Error)
    /// Invalid account when trying to derive spending key
    /// ZDRVT0001
    case derivationToolSpendingKeyInvalidAccount
    /// Creation of the table for unspent transaction output failed.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZUTOD0001
    case unspentTransactionOutputDAOCreateTable(_ sqliteError: Error)
    /// SQLite query failed when storing unspent transaction output.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZUTOD0002
    case unspentTransactionOutputDAOStore(_ sqliteError: Error)
    /// SQLite query failed when removing all the unspent transation outputs.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZUTOD0003
    case unspentTransactionOutputDAOClearAll(_ sqliteError: Error)
    /// Fetched information about unspent transaction output from the DB but it can't be decoded to `UTXO` object.
    /// - `error` decoding error.
    /// ZUTOD0004
    case unspentTransactionOutputDAOGetAllCantDecode(_ error: Error)
    /// SQLite query failed when getting all the unspent transation outputs.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZUTOD0005
    case unspentTransactionOutputDAOGetAll(_ sqliteError: Error)
    /// SQLite query failed when getting balance.
    /// - `sqliteError` is error produced by SQLite library.
    /// ZUTOD0006
    case unspentTransactionOutputDAOBalance(_ sqliteError: Error)
    /// Can't create `SaplingExtendedSpendingKey` because input is invalid.
    /// ZWLTP0001
    case spendingKeyInvalidInput
    /// Can't create `UnifiedFullViewingKey` because input is invalid.
    /// ZWLTP0002
    case unifiedFullViewingKeyInvalidInput
    /// Can't create `SaplingExtendedFullViewingKey` because input is invalid.
    /// ZWLTP0003
    case extetendedFullViewingKeyInvalidInput
    /// Can't create `TransparentAddress` because input is invalid.
    /// ZWLTP0004
    case transparentAddressInvalidInput
    /// Can't create `SaplingAddress` because input is invalid.
    /// ZWLTP0005
    case saplingAddressInvalidInput
    /// Can't create `UnifiedAddress` because input is invalid.
    /// ZWLTP0006
    case unifiedAddressInvalidInput
    /// Can't create `Recipient` because input is invalid.
    /// ZWLTP0007
    case recipientInvalidInput
    /// WalletTransactionEncoder wants to create transaction but files with sapling parameters are not present on disk.
    /// ZWLTE0001
    case walletTransEncoderCreateTransactionMissingSaplingParams
    /// WalletTransactionEncoder wants to shield funds but files with sapling parameters are not present on disk.
    /// ZWLTE0002
    case walletTransEncoderShieldFundsMissingSaplingParams
    /// PersistentTransactionsManager cant create transaction.
    /// ZPTRM0001
    case persistentTransManagerCantCreateTransaction(_ recipient: PendingTransactionRecipient, _ account: Int, _ zatoshi: Zatoshi)
    /// PersistentTransactionsManager cant get to address from pending transaction.
    /// ZPTRM0002
    case persistentTransManagerEncodeUknownToAddress(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to submit pending transaction but transaction is missing id.
    /// ZPTRM0003
    case persistentTransManagerSubmitTransactionIDMissing(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to submit pending transaction but transaction is missing id. Transaction is probably not stored.
    /// ZPTRM0004
    case persistentTransManagerSubmitTransactionNotFound(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to submit pending transaction but transaction is canceled.
    /// ZPTRM0005
    case persistentTransManagerSubmitTransactionCanceled(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to submit pending transaction but transaction is missing raw data.
    /// ZPTRM0006
    case persistentTransManagerSubmitTransactionRawDataMissing(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to submit pending transaction but submit API call failed.
    /// ZPTRM0007
    case persistentTransManagerSubmitFailed(_ entity: PendingTransactionEntity, _ serviceErrorCode: Int)
    /// PersistentTransactionsManager wants to apply mined height to transaction but transaction is missing id. Transaction is probably not stored.
    /// ZPTRM0008
    case persistentTransManagerApplyMinedHeightTransactionIDMissing(_ entity: PendingTransactionEntity)
    /// PersistentTransactionsManager wants to apply mined height to transaction but transaction is not found in storage. Transaction is probably not stored.
    /// ZPTRM0009
    case persistentTransManagerApplyMinedHeightTransactionNotFound(_ entity: PendingTransactionEntity)
    /// Initiatilzation fo `Zatoshi` from a decoder failed.
    /// ZTSHO0001
    case zatoshiDecode(_ error: Error)
    /// Encode of `Zatoshi` failed.
    /// ZTSHO0002
    case zatoshiEncode(_ error: Error)
    /// Awaiting transactions from the stream failed.
    /// ZUTXO0001
    case unspentTransactionFetcherStream(_ error: Error)
    /// CompactBlockProcessor was started with an invalid configuration.
    /// ZCBPEO0001
    case compactBlockProcessorInvalidConfiguration
    /// CompactBlockProcessor was set up with path but that location couldn't be reached.
    /// ZCBPEO0002
    case compactBlockProcessorMissingDbPath(_ path: String)
    /// Data Db file couldn't be initialized at path.
    /// ZCBPEO0003
    case compactBlockProcessorDataDbInitFailed(_ path: String)
    /// There's a problem with the network connection.
    /// ZCBPEO0004
    case compactBlockProcessorConnection(_ underlyingError: Error)
    /// Error on gRPC happened.
    /// ZCBPEO0005
    case compactBlockProcessorGrpcError(_ statusCode: Int, _ message: String)
    /// Network connection timeout.
    /// ZCBPEO0006
    case compactBlockProcessorConnectionTimeout
    /// Compact Block failed and reached the maximum amount of retries it was set up to do.
    /// ZCBPEO0007
    case compactBlockProcessorMaxAttemptsReached(_ attempts: Int)
    /// Unspecified error occured.
    /// ZCBPEO0008
    case compactBlockProcessorUnspecified(_ underlyingError: Error)
    /// Critical error occured.
    /// ZCBPEO0009
    case compactBlockProcessorCritical
    /// Invalid Account.
    /// ZCBPEO0010
    case compactBlockProcessorInvalidAccount
    /// The remote server you are connecting to is publishing a different branch ID than the one your App is expecting This could be caused by your App being out of date or the server you are connecting you being either on a different network or out of date after a network upgrade.
    /// ZCBPEO0011
    case compactBlockProcessorWrongConsensusBranchId(_ expectedLocally: ConsensusBranchID, _ found: ConsensusBranchID)
    /// A server was reached, but it's targeting the wrong network Type. Make sure you are pointing to the right server.
    /// ZCBPEO0012
    case compactBlockProcessorNetworkMismatch(_ expected: NetworkType, _ found: NetworkType)
    /// A server was reached, it's showing a different sapling activation. Are you sure you are pointing to the right server?
    /// ZCBPEO0013
    case compactBlockProcessorSaplingActivationMismatch(_ expected: BlockHeight, _ found: BlockHeight)
    /// when the given URL is the same URL than the one provided as `self.fsBlockDbRoot` assuming that's a programming error being the `legacyCacheDbURL` a sqlite database file and not a directory
    /// ZCBPEO0014
    case compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL
    /// Deletion of readable file at the provided URL failed.
    /// ZCBPEO0015
    case compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb(_ error: Error)
    /// Chain name does not match. Expected either 'test' or 'main'. This is probably an API or programming error.
    /// ZCBPEO0016
    case compactBlockProcessorChainName(_ name: String)
    /// Consensus BranchIDs don't match this is probably an API or programming error.
    /// ZCBPEO0017
    case compactBlockProcessorConsensusBranchID
    /// The synchronizer is unprepared.
    /// ZSYNCO0001
    case synchronizerNotPrepared
    /// Memos can't be sent to transparent addresses.
    /// ZSYNCO0002
    case synchronizerSendMemoToTransparentAddress
    /// There is not enough transparent funds to cover fee for the shielding.
    /// ZSYNCO0003
    case synchronizerShieldFundsInsuficientTransparentFunds
    /// LatestUTXOs for the address failed, invalid t-address.
    /// ZSYNCO0004
    case synchronizerLatestUTXOsInvalidTAddress
    /// Rewind failed, unknown archor height
    /// ZSYNCO0005
    case synchronizerRewindUnknownArchorHeight

    public var message: String {
        switch self {
        case .initializerCantUpdateURLWithAlias: return "Updating of paths in `Initilizer` according to alias failed."
        case .initializerAliasAlreadyInUse: return "Alias used to create this instance of the `SDKSynchronizer` is already used by other instance."
        case .serviceUnknownError: return "Unknown GRPC Service error"
        case .serviceGetInfoFailed: return "LightWalletService.getInfo failed."
        case .serviceLatestBlockFailed: return "LightWalletService.latestBlock failed."
        case .serviceLatestBlockHeightFailed: return "LightWalletService.latestBlockHeight failed."
        case .serviceBlockRangeFailed: return "LightWalletService.blockRange failed."
        case .serviceSubmitFailed: return "LightWalletService.submit failed."
        case .serviceFetchTransactionFailed: return "LightWalletService.fetchTransaction failed."
        case .serviceFetchUTXOsFailed: return "LightWalletService.fetchUTXOs failed."
        case .serviceBlockStreamFailed: return "LightWalletService.blockStream failed."
        case .dbMigrationGenericFailure: return "Migration of the pending DB failed because of unspecific reason."
        case .dbMigrationInvalidVersion: return "Migration of the pending DB failed because unknown version of the existing database."
        case .dbMigrationV1: return "Migration of the pending DB to version 1 failed."
        case .dbMigrationV2: return "Migration of the pending DB to version 2 failed."
        case .simpleConnectionProvider: return "SimpleConnectionProvider init of Connection failed."
        case .saplingParamsInvalidSpendParams: return "Downloaded file with sapling spending parameters isn't valid."
        case .saplingParamsInvalidOutputParams: return "Downloaded file with sapling output parameters isn't valid."
        case .saplingParamsDownload: return "Failed to download sapling parameters file"
        case .saplingParamsCantMoveDownloadedFile: return "Failed to move sapling parameters file to final destination after download."
        case .notesDAOReceivedCount: return "SQLite query failed when fetching received notes count from the database."
        case .notesDAOReceivedNote: return "SQLite query failed when fetching received notes from the database."
        case .notesDAOReceivedCantDecode: return "Fetched note from the SQLite but can't decode that."
        case .notesDAOSentCount: return "SQLite query failed when fetching sent notes count from the database."
        case .notesDAOSentNote: return "SQLite query failed when fetching sent notes from the database."
        case .notesDAOSentCantDecode: return "Fetched note from the SQLite but can't decode that."
        case .blockDAOBlock: return "SQLite query failed when fetching block information from database."
        case .blockDAOCantDecode: return "Fetched block information from DB but can't decode them."
        case .blockDAOLatestBlockHeight: return "SQLite query failed when fetching height of the latest block from the database."
        case .blockDAOLatestBlock: return "SQLite query failed when fetching the latest block from the database."
        case .blockDAOLatestBlockCantDecode: return "Fetched latesxt block information from DB but can't decode them."
        case .rustCreateAccount: return "Error from rust layer when calling ZcashRustBackend.createAccount"
        case .rustCreateToAddress: return "Error from rust layer when calling ZcashRustBackend.createToAddress"
        case .rustDecryptAndStoreTransaction: return "Error from rust layer when calling ZcashRustBackend.decryptAndStoreTransaction"
        case .rustGetBalance: return "Error from rust layer when calling ZcashRustBackend.getBalance"
        case .rustGetCurrentAddress: return "Error from rust layer when calling ZcashRustBackend.getCurrentAddress"
        case .rustGetCurrentAddressInvalidAddress: return "Unified address generated by rust layer is invalid when calling ZcashRustBackend.getCurrentAddress"
        case .rustGetNearestRewindHeight: return "Error from rust layer when calling ZcashRustBackend.getNearestRewindHeight"
        case .rustGetNextAvailableAddress: return "Error from rust layer when calling ZcashRustBackend.getNextAvailableAddress"
        case .rustGetNextAvailableAddressInvalidAddress: return "Unified address generated by rust layer is invalid when calling ZcashRustBackend.getNextAvailableAddress"
        case .rustGetTransparentBalanceNegativeAccount: return "account parameter is lower than 0 when calling ZcashRustBackend.getTransparentBalance"
        case .rustGetTransparentBalance: return "Error from rust layer when calling ZcashRustBackend.getTransparentBalance"
        case .rustGetVerifiedBalance: return "Error from rust layer when calling ZcashRustBackend.getVerifiedBalance"
        case .rustGetVerifiedTransparentBalanceNegativeAccount: return "account parameter is lower than 0 when calling ZcashRustBackend.getVerifiedTransparentBalance"
        case .rustGetVerifiedTransparentBalance: return "Error from rust layer when calling ZcashRustBackend.getVerifiedTransparentBalance"
        case .rustInitDataDb: return "Error from rust layer when calling ZcashRustBackend.initDataDb"
        case .rustInitAccountsTableViewingKeyCotainsNullBytes: return "Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method contains null bytes before end"
        case .rustInitAccountsTableViewingKeyIsInvalid: return "Any of the viewing keys passed to the ZcashRustBackend.initAccountsTable method isn't valid"
        case .rustInitAccountsTableDataDbNotEmpty: return "Error from rust layer when calling ZcashRustBackend.initAccountsTable"
        case .rustInitAccountsTable: return "Error from rust layer when calling ZcashRustBackend.initAccountsTable"
        case .rustInitBlockMetadataDb: return "Error from rust layer when calling ZcashRustBackend.initBlockMetadataDb"
        case .rustWriteBlocksMetadataAllocationProblem: return "Unable to allocate memory required to write blocks when calling ZcashRustBackend.writeBlocksMetadata"
        case .rustWriteBlocksMetadata: return "Error from rust layer when calling ZcashRustBackend.writeBlocksMetadata"
        case .rustInitBlocksTableHashContainsNullBytes: return "hash passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end"
        case .rustInitBlocksTableSaplingTreeContainsNullBytes: return "saplingTree passed to the ZcashRustBackend.initBlocksTable method contains null bytes before end"
        case .rustInitBlocksTableDataDbNotEmpty: return "Error from rust layer when calling ZcashRustBackend.initBlocksTable"
        case .rustInitBlocksTable: return "Error from rust layer when calling ZcashRustBackend.initBlocksTable"
        case .rustListTransparentReceivers: return "Error from rust layer when calling ZcashRustBackend.listTransparentReceivers"
        case .rustListTransparentReceiversInvalidAddress: return "Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.listTransparentReceivers"
        case .rustPutUnspentTransparentOutput: return "Error from rust layer when calling ZcashRustBackend.putUnspentTransparentOutput"
        case .rustValidateCombinedChainValidationFailed: return "Error unrelated to chain validity from rust layer when calling ZcashRustBackend.validateCombinedChain"
        case .rustValidateCombinedChainInvalidChain: return "Error from rust layer which means that combined chain isn't valid."
        case .rustRewindToHeight: return "Error from rust layer when calling ZcashRustBackend.rewindToHeight"
        case .rustRewindCacheToHeight: return "Error from rust layer when calling ZcashRustBackend.rewindCacheToHeight"
        case .rustScanBlocks: return "Error from rust layer when calling ZcashRustBackend.scanBlocks"
        case .rustShieldFunds: return "Error from rust layer when calling ZcashRustBackend.shieldFunds"
        case .rustNoConsensusBranchId: return "Error from rust layer when calling ZcashRustBackend.consensusBranchIdFor"
        case .rustReceiverTypecodesOnUnifiedAddressContainsNullBytes: return "address passed to the ZcashRustBackend.receiverTypecodesOnUnifiedAddress method contains null bytes before end"
        case .rustRustReceiverTypecodesOnUnifiedAddressMalformed: return "Error from rust layer when calling ZcashRustBackend.receiverTypecodesOnUnifiedAddress"
        case .rustDeriveUnifiedSpendingKey: return "Error from rust layer when calling ZcashRustBackend.deriveUnifiedSpendingKey"
        case .rustDeriveUnifiedFullViewingKey: return "Error from rust layer when calling ZcashRustBackend.deriveUnifiedFullViewingKey"
        case .rustDeriveUnifiedFullViewingKeyInvalidDerivedKey: return "Viewing key derived by rust layer is invalid when calling ZcashRustBackend.deriveUnifiedFullViewingKey"
        case .rustGetSaplingReceiverInvalidAddress: return "Error from rust layer when calling ZcashRustBackend.getSaplingReceiver"
        case .rustGetSaplingReceiverInvalidReceiver: return "Sapling receiver generated by rust layer is invalid when calling ZcashRustBackend.getSaplingReceiver"
        case .rustGetTransparentReceiverInvalidAddress: return "Error from rust layer when calling ZcashRustBackend.getTransparentReceiver"
        case .rustGetTransparentReceiverInvalidReceiver: return "Transparent receiver generated by rust layer is invalid when calling ZcashRustBackend.getTransparentReceiver"
        case .accountDAOGetAll: return "SQLite query failed when fetching all accounts from the database."
        case .accountDAOGetAllCantDecode: return "Fetched accounts from SQLite but can't decode them."
        case .accountDAOFindBy: return "SQLite query failed when seaching for accounts in the database."
        case .accountDAOFindByCantDecode: return "Fetched accounts from SQLite but can't decode them."
        case .accountDAOUpdateInvalidAccount: return "Object passed to update() method conforms to `AccountEntity` protocol but isn't exactly `Account` type."
        case .accountDAOUpdate: return "SQLite query failed when updating account in the database."
        case .accountDAOUpdatedZeroRows: return "Update of the account updated 0 rows in the database. One row should be updated."
        case .blockRepositoryWriteBlock: return "Failed to write block to disk."
        case .blockRepositoryGetFilename: return "Failed to get filename for the block from file URL."
        case .blockRepositoryParseHeightFromFilename: return "Failed to parse block height from filename."
        case .blockRepositoryRemoveExistingBlock: return "Failed to remove existing block from disk."
        case .blockRepositoryGetFilenameAndIsDirectory: return "Failed to get filename and information if url points to directory from file URL."
        case .blockRepositoryCreateBlocksCacheDirectory: return "Failed to create blocks cache directory."
        case .blockRepositoryReadDirectoryContent: return "Failed to read content of directory."
        case .blockRepositoryRemoveBlockAfterRewind: return "Failed to remove block from disk after rewind operation."
        case .blockRepositoryRemoveBlocksCacheDirectory: return "Failed to remove blocks cache directory while clearing storage."
        case .blockDownloaderServiceDownloadBlockRange: return "Stream downloading the given block range failed."
        case .zcashTransactionOverviewInit: return "Initialization of `ZcashTransaction.Overview` failed."
        case .zcashTransactionReceivedInit: return "Initialization of `ZcashTransaction.Received` failed."
        case .zcashTransactionSentInit: return "Initialization of `ZcashTransaction.Sent` failed."
        case .transactionRepositoryEntityNotFound: return "Entity not found in the database, result of `createEntity` execution."
        case .transactionRepositoryTransactionMissingRequiredFields: return "`Find` call is missing fields, required fields are transaction `index` and `blockTime`."
        case .transactionRepositoryCountAll: return "Counting all transactions failed."
        case .transactionRepositoryCountUnmined: return "Counting all unmined transactions failed."
        case .transactionRepositoryQueryExecute: return "Execution of a query failed."
        case .transactionRepositoryFindMemos: return "Finding memos in the database failed."
        case .compactBlockEncode: return "Can't encode `ZcashCompactBlock` object."
        case .memoTextInvalidUTF8: return "Invalid UTF-8 Bytes where detected when attempting to create a MemoText."
        case .memoTextInputEndsWithNullBytes: return "Trailing null-bytes were found when attempting to create a MemoText."
        case .memoTextInputTooLong: return "The resulting bytes provided are too long to be stored as a MemoText."
        case .memoBytesInputTooLong: return "The resulting bytes provided are too long to be stored as a MemoBytes."
        case .memoBytesInvalidUTF8: return "Invalid UTF-8 Bytes where detected when attempting to convert MemoBytes to Memo."
        case .checkpointCantLoadFromDisk: return "Failed to load JSON with checkpoint from disk."
        case .checkpointDecode: return "Failed to decode `Checkpoint` object."
        case .pendingTransactionDecodeInvalidData: return "Decoding of `PendingTransaction` failed because of specific invalid data."
        case .pendingTransactionCantDecode: return "Can't decode `PendingTransaction`."
        case .pendingTransactionCantEncode: return "Can't encode `PendingTransaction`."
        case .pendingTransactionDAOCreate: return "SQLite query failed when creating pending transaction."
        case .pendingTransactionDAOUpdateMissingID: return "Pending transaction which should be updated is missing ID."
        case .pendingTransactionDAOUpdate: return "SQLite query failed when updating pending transaction."
        case .pendingTransactionDAODeleteMissingID: return "Pending transaction which should be deleted is missing ID."
        case .pendingTransactionDAODelete: return "SQLite query failed when deleting pending transaction."
        case .pendingTransactionDAOCancelMissingID: return "Pending transaction which should be canceled is missing ID."
        case .pendingTransactionDAOCancel: return "SQLite query failed when canceling pending transaction."
        case .pendingTransactionDAOFind: return "SQLite query failed when seaching for pending transaction."
        case .pendingTransactionDAOGetAll: return "SQLite query failed when getting pending transactions."
        case .pendingTransactionDAOApplyMinedHeight: return "SQLite query failed when applying mined height."
        case .derivationToolSpendingKeyInvalidAccount: return "Invalid account when trying to derive spending key"
        case .unspentTransactionOutputDAOCreateTable: return "Creation of the table for unspent transaction output failed."
        case .unspentTransactionOutputDAOStore: return "SQLite query failed when storing unspent transaction output."
        case .unspentTransactionOutputDAOClearAll: return "SQLite query failed when removing all the unspent transation outputs."
        case .unspentTransactionOutputDAOGetAllCantDecode: return "Fetched information about unspent transaction output from the DB but it can't be decoded to `UTXO` object."
        case .unspentTransactionOutputDAOGetAll: return "SQLite query failed when getting all the unspent transation outputs."
        case .unspentTransactionOutputDAOBalance: return "SQLite query failed when getting balance."
        case .spendingKeyInvalidInput: return "Can't create `SaplingExtendedSpendingKey` because input is invalid."
        case .unifiedFullViewingKeyInvalidInput: return "Can't create `UnifiedFullViewingKey` because input is invalid."
        case .extetendedFullViewingKeyInvalidInput: return "Can't create `SaplingExtendedFullViewingKey` because input is invalid."
        case .transparentAddressInvalidInput: return "Can't create `TransparentAddress` because input is invalid."
        case .saplingAddressInvalidInput: return "Can't create `SaplingAddress` because input is invalid."
        case .unifiedAddressInvalidInput: return "Can't create `UnifiedAddress` because input is invalid."
        case .recipientInvalidInput: return "Can't create `Recipient` because input is invalid."
        case .walletTransEncoderCreateTransactionMissingSaplingParams: return "WalletTransactionEncoder wants to create transaction but files with sapling parameters are not present on disk."
        case .walletTransEncoderShieldFundsMissingSaplingParams: return "WalletTransactionEncoder wants to shield funds but files with sapling parameters are not present on disk."
        case .persistentTransManagerCantCreateTransaction: return "PersistentTransactionsManager cant create transaction."
        case .persistentTransManagerEncodeUknownToAddress: return "PersistentTransactionsManager cant get to address from pending transaction."
        case .persistentTransManagerSubmitTransactionIDMissing: return "PersistentTransactionsManager wants to submit pending transaction but transaction is missing id."
        case .persistentTransManagerSubmitTransactionNotFound: return "PersistentTransactionsManager wants to submit pending transaction but transaction is missing id. Transaction is probably not stored."
        case .persistentTransManagerSubmitTransactionCanceled: return "PersistentTransactionsManager wants to submit pending transaction but transaction is canceled."
        case .persistentTransManagerSubmitTransactionRawDataMissing: return "PersistentTransactionsManager wants to submit pending transaction but transaction is missing raw data."
        case .persistentTransManagerSubmitFailed: return "PersistentTransactionsManager wants to submit pending transaction but submit API call failed."
        case .persistentTransManagerApplyMinedHeightTransactionIDMissing: return "PersistentTransactionsManager wants to apply mined height to transaction but transaction is missing id. Transaction is probably not stored."
        case .persistentTransManagerApplyMinedHeightTransactionNotFound: return "PersistentTransactionsManager wants to apply mined height to transaction but transaction is not found in storage. Transaction is probably not stored."
        case .zatoshiDecode: return "Initiatilzation fo `Zatoshi` from a decoder failed."
        case .zatoshiEncode: return "Encode of `Zatoshi` failed."
        case .unspentTransactionFetcherStream: return "Awaiting transactions from the stream failed."
        case .compactBlockProcessorInvalidConfiguration: return "CompactBlockProcessor was started with an invalid configuration."
        case .compactBlockProcessorMissingDbPath: return "CompactBlockProcessor was set up with path but that location couldn't be reached."
        case .compactBlockProcessorDataDbInitFailed: return "Data Db file couldn't be initialized at path."
        case .compactBlockProcessorConnection: return "There's a problem with the network connection."
        case .compactBlockProcessorGrpcError: return "Error on gRPC happened."
        case .compactBlockProcessorConnectionTimeout: return "Network connection timeout."
        case .compactBlockProcessorMaxAttemptsReached: return "Compact Block failed and reached the maximum amount of retries it was set up to do."
        case .compactBlockProcessorUnspecified: return "Unspecified error occured."
        case .compactBlockProcessorCritical: return "Critical error occured."
        case .compactBlockProcessorInvalidAccount: return "Invalid Account."
        case .compactBlockProcessorWrongConsensusBranchId: return "The remote server you are connecting to is publishing a different branch ID than the one your App is expecting This could be caused by your App being out of date or the server you are connecting you being either on a different network or out of date after a network upgrade."
        case .compactBlockProcessorNetworkMismatch: return "A server was reached, but it's targeting the wrong network Type. Make sure you are pointing to the right server."
        case .compactBlockProcessorSaplingActivationMismatch: return "A server was reached, it's showing a different sapling activation. Are you sure you are pointing to the right server?"
        case .compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL: return "when the given URL is the same URL than the one provided as `self.fsBlockDbRoot` assuming that's a programming error being the `legacyCacheDbURL` a sqlite database file and not a directory"
        case .compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb: return "Deletion of readable file at the provided URL failed."
        case .compactBlockProcessorChainName: return "Chain name does not match. Expected either 'test' or 'main'. This is probably an API or programming error."
        case .compactBlockProcessorConsensusBranchID: return "Consensus BranchIDs don't match this is probably an API or programming error."
        case .synchronizerNotPrepared: return "The synchronizer is unprepared."
        case .synchronizerSendMemoToTransparentAddress: return "Memos can't be sent to transparent addresses."
        case .synchronizerShieldFundsInsuficientTransparentFunds: return "There is not enough transparent funds to cover fee for the shielding."
        case .synchronizerLatestUTXOsInvalidTAddress: return "LatestUTXOs for the address failed, invalid t-address."
        case .synchronizerRewindUnknownArchorHeight: return "Rewind failed, unknown archor height"
        }
    }

    public var code: ZcashErrorCode {
        switch self {
        case .initializerCantUpdateURLWithAlias: return .initializerCantUpdateURLWithAlias
        case .initializerAliasAlreadyInUse: return .initializerAliasAlreadyInUse
        case .serviceUnknownError: return .serviceUnknownError
        case .serviceGetInfoFailed: return .serviceGetInfoFailed
        case .serviceLatestBlockFailed: return .serviceLatestBlockFailed
        case .serviceLatestBlockHeightFailed: return .serviceLatestBlockHeightFailed
        case .serviceBlockRangeFailed: return .serviceBlockRangeFailed
        case .serviceSubmitFailed: return .serviceSubmitFailed
        case .serviceFetchTransactionFailed: return .serviceFetchTransactionFailed
        case .serviceFetchUTXOsFailed: return .serviceFetchUTXOsFailed
        case .serviceBlockStreamFailed: return .serviceBlockStreamFailed
        case .dbMigrationGenericFailure: return .dbMigrationGenericFailure
        case .dbMigrationInvalidVersion: return .dbMigrationInvalidVersion
        case .dbMigrationV1: return .dbMigrationV1
        case .dbMigrationV2: return .dbMigrationV2
        case .simpleConnectionProvider: return .simpleConnectionProvider
        case .saplingParamsInvalidSpendParams: return .saplingParamsInvalidSpendParams
        case .saplingParamsInvalidOutputParams: return .saplingParamsInvalidOutputParams
        case .saplingParamsDownload: return .saplingParamsDownload
        case .saplingParamsCantMoveDownloadedFile: return .saplingParamsCantMoveDownloadedFile
        case .notesDAOReceivedCount: return .notesDAOReceivedCount
        case .notesDAOReceivedNote: return .notesDAOReceivedNote
        case .notesDAOReceivedCantDecode: return .notesDAOReceivedCantDecode
        case .notesDAOSentCount: return .notesDAOSentCount
        case .notesDAOSentNote: return .notesDAOSentNote
        case .notesDAOSentCantDecode: return .notesDAOSentCantDecode
        case .blockDAOBlock: return .blockDAOBlock
        case .blockDAOCantDecode: return .blockDAOCantDecode
        case .blockDAOLatestBlockHeight: return .blockDAOLatestBlockHeight
        case .blockDAOLatestBlock: return .blockDAOLatestBlock
        case .blockDAOLatestBlockCantDecode: return .blockDAOLatestBlockCantDecode
        case .rustCreateAccount: return .rustCreateAccount
        case .rustCreateToAddress: return .rustCreateToAddress
        case .rustDecryptAndStoreTransaction: return .rustDecryptAndStoreTransaction
        case .rustGetBalance: return .rustGetBalance
        case .rustGetCurrentAddress: return .rustGetCurrentAddress
        case .rustGetCurrentAddressInvalidAddress: return .rustGetCurrentAddressInvalidAddress
        case .rustGetNearestRewindHeight: return .rustGetNearestRewindHeight
        case .rustGetNextAvailableAddress: return .rustGetNextAvailableAddress
        case .rustGetNextAvailableAddressInvalidAddress: return .rustGetNextAvailableAddressInvalidAddress
        case .rustGetTransparentBalanceNegativeAccount: return .rustGetTransparentBalanceNegativeAccount
        case .rustGetTransparentBalance: return .rustGetTransparentBalance
        case .rustGetVerifiedBalance: return .rustGetVerifiedBalance
        case .rustGetVerifiedTransparentBalanceNegativeAccount: return .rustGetVerifiedTransparentBalanceNegativeAccount
        case .rustGetVerifiedTransparentBalance: return .rustGetVerifiedTransparentBalance
        case .rustInitDataDb: return .rustInitDataDb
        case .rustInitAccountsTableViewingKeyCotainsNullBytes: return .rustInitAccountsTableViewingKeyCotainsNullBytes
        case .rustInitAccountsTableViewingKeyIsInvalid: return .rustInitAccountsTableViewingKeyIsInvalid
        case .rustInitAccountsTableDataDbNotEmpty: return .rustInitAccountsTableDataDbNotEmpty
        case .rustInitAccountsTable: return .rustInitAccountsTable
        case .rustInitBlockMetadataDb: return .rustInitBlockMetadataDb
        case .rustWriteBlocksMetadataAllocationProblem: return .rustWriteBlocksMetadataAllocationProblem
        case .rustWriteBlocksMetadata: return .rustWriteBlocksMetadata
        case .rustInitBlocksTableHashContainsNullBytes: return .rustInitBlocksTableHashContainsNullBytes
        case .rustInitBlocksTableSaplingTreeContainsNullBytes: return .rustInitBlocksTableSaplingTreeContainsNullBytes
        case .rustInitBlocksTableDataDbNotEmpty: return .rustInitBlocksTableDataDbNotEmpty
        case .rustInitBlocksTable: return .rustInitBlocksTable
        case .rustListTransparentReceivers: return .rustListTransparentReceivers
        case .rustListTransparentReceiversInvalidAddress: return .rustListTransparentReceiversInvalidAddress
        case .rustPutUnspentTransparentOutput: return .rustPutUnspentTransparentOutput
        case .rustValidateCombinedChainValidationFailed: return .rustValidateCombinedChainValidationFailed
        case .rustValidateCombinedChainInvalidChain: return .rustValidateCombinedChainInvalidChain
        case .rustRewindToHeight: return .rustRewindToHeight
        case .rustRewindCacheToHeight: return .rustRewindCacheToHeight
        case .rustScanBlocks: return .rustScanBlocks
        case .rustShieldFunds: return .rustShieldFunds
        case .rustNoConsensusBranchId: return .rustNoConsensusBranchId
        case .rustReceiverTypecodesOnUnifiedAddressContainsNullBytes: return .rustReceiverTypecodesOnUnifiedAddressContainsNullBytes
        case .rustRustReceiverTypecodesOnUnifiedAddressMalformed: return .rustRustReceiverTypecodesOnUnifiedAddressMalformed
        case .rustDeriveUnifiedSpendingKey: return .rustDeriveUnifiedSpendingKey
        case .rustDeriveUnifiedFullViewingKey: return .rustDeriveUnifiedFullViewingKey
        case .rustDeriveUnifiedFullViewingKeyInvalidDerivedKey: return .rustDeriveUnifiedFullViewingKeyInvalidDerivedKey
        case .rustGetSaplingReceiverInvalidAddress: return .rustGetSaplingReceiverInvalidAddress
        case .rustGetSaplingReceiverInvalidReceiver: return .rustGetSaplingReceiverInvalidReceiver
        case .rustGetTransparentReceiverInvalidAddress: return .rustGetTransparentReceiverInvalidAddress
        case .rustGetTransparentReceiverInvalidReceiver: return .rustGetTransparentReceiverInvalidReceiver
        case .accountDAOGetAll: return .accountDAOGetAll
        case .accountDAOGetAllCantDecode: return .accountDAOGetAllCantDecode
        case .accountDAOFindBy: return .accountDAOFindBy
        case .accountDAOFindByCantDecode: return .accountDAOFindByCantDecode
        case .accountDAOUpdateInvalidAccount: return .accountDAOUpdateInvalidAccount
        case .accountDAOUpdate: return .accountDAOUpdate
        case .accountDAOUpdatedZeroRows: return .accountDAOUpdatedZeroRows
        case .blockRepositoryWriteBlock: return .blockRepositoryWriteBlock
        case .blockRepositoryGetFilename: return .blockRepositoryGetFilename
        case .blockRepositoryParseHeightFromFilename: return .blockRepositoryParseHeightFromFilename
        case .blockRepositoryRemoveExistingBlock: return .blockRepositoryRemoveExistingBlock
        case .blockRepositoryGetFilenameAndIsDirectory: return .blockRepositoryGetFilenameAndIsDirectory
        case .blockRepositoryCreateBlocksCacheDirectory: return .blockRepositoryCreateBlocksCacheDirectory
        case .blockRepositoryReadDirectoryContent: return .blockRepositoryReadDirectoryContent
        case .blockRepositoryRemoveBlockAfterRewind: return .blockRepositoryRemoveBlockAfterRewind
        case .blockRepositoryRemoveBlocksCacheDirectory: return .blockRepositoryRemoveBlocksCacheDirectory
        case .blockDownloaderServiceDownloadBlockRange: return .blockDownloaderServiceDownloadBlockRange
        case .zcashTransactionOverviewInit: return .zcashTransactionOverviewInit
        case .zcashTransactionReceivedInit: return .zcashTransactionReceivedInit
        case .zcashTransactionSentInit: return .zcashTransactionSentInit
        case .transactionRepositoryEntityNotFound: return .transactionRepositoryEntityNotFound
        case .transactionRepositoryTransactionMissingRequiredFields: return .transactionRepositoryTransactionMissingRequiredFields
        case .transactionRepositoryCountAll: return .transactionRepositoryCountAll
        case .transactionRepositoryCountUnmined: return .transactionRepositoryCountUnmined
        case .transactionRepositoryQueryExecute: return .transactionRepositoryQueryExecute
        case .transactionRepositoryFindMemos: return .transactionRepositoryFindMemos
        case .compactBlockEncode: return .compactBlockEncode
        case .memoTextInvalidUTF8: return .memoTextInvalidUTF8
        case .memoTextInputEndsWithNullBytes: return .memoTextInputEndsWithNullBytes
        case .memoTextInputTooLong: return .memoTextInputTooLong
        case .memoBytesInputTooLong: return .memoBytesInputTooLong
        case .memoBytesInvalidUTF8: return .memoBytesInvalidUTF8
        case .checkpointCantLoadFromDisk: return .checkpointCantLoadFromDisk
        case .checkpointDecode: return .checkpointDecode
        case .pendingTransactionDecodeInvalidData: return .pendingTransactionDecodeInvalidData
        case .pendingTransactionCantDecode: return .pendingTransactionCantDecode
        case .pendingTransactionCantEncode: return .pendingTransactionCantEncode
        case .pendingTransactionDAOCreate: return .pendingTransactionDAOCreate
        case .pendingTransactionDAOUpdateMissingID: return .pendingTransactionDAOUpdateMissingID
        case .pendingTransactionDAOUpdate: return .pendingTransactionDAOUpdate
        case .pendingTransactionDAODeleteMissingID: return .pendingTransactionDAODeleteMissingID
        case .pendingTransactionDAODelete: return .pendingTransactionDAODelete
        case .pendingTransactionDAOCancelMissingID: return .pendingTransactionDAOCancelMissingID
        case .pendingTransactionDAOCancel: return .pendingTransactionDAOCancel
        case .pendingTransactionDAOFind: return .pendingTransactionDAOFind
        case .pendingTransactionDAOGetAll: return .pendingTransactionDAOGetAll
        case .pendingTransactionDAOApplyMinedHeight: return .pendingTransactionDAOApplyMinedHeight
        case .derivationToolSpendingKeyInvalidAccount: return .derivationToolSpendingKeyInvalidAccount
        case .unspentTransactionOutputDAOCreateTable: return .unspentTransactionOutputDAOCreateTable
        case .unspentTransactionOutputDAOStore: return .unspentTransactionOutputDAOStore
        case .unspentTransactionOutputDAOClearAll: return .unspentTransactionOutputDAOClearAll
        case .unspentTransactionOutputDAOGetAllCantDecode: return .unspentTransactionOutputDAOGetAllCantDecode
        case .unspentTransactionOutputDAOGetAll: return .unspentTransactionOutputDAOGetAll
        case .unspentTransactionOutputDAOBalance: return .unspentTransactionOutputDAOBalance
        case .spendingKeyInvalidInput: return .spendingKeyInvalidInput
        case .unifiedFullViewingKeyInvalidInput: return .unifiedFullViewingKeyInvalidInput
        case .extetendedFullViewingKeyInvalidInput: return .extetendedFullViewingKeyInvalidInput
        case .transparentAddressInvalidInput: return .transparentAddressInvalidInput
        case .saplingAddressInvalidInput: return .saplingAddressInvalidInput
        case .unifiedAddressInvalidInput: return .unifiedAddressInvalidInput
        case .recipientInvalidInput: return .recipientInvalidInput
        case .walletTransEncoderCreateTransactionMissingSaplingParams: return .walletTransEncoderCreateTransactionMissingSaplingParams
        case .walletTransEncoderShieldFundsMissingSaplingParams: return .walletTransEncoderShieldFundsMissingSaplingParams
        case .persistentTransManagerCantCreateTransaction: return .persistentTransManagerCantCreateTransaction
        case .persistentTransManagerEncodeUknownToAddress: return .persistentTransManagerEncodeUknownToAddress
        case .persistentTransManagerSubmitTransactionIDMissing: return .persistentTransManagerSubmitTransactionIDMissing
        case .persistentTransManagerSubmitTransactionNotFound: return .persistentTransManagerSubmitTransactionNotFound
        case .persistentTransManagerSubmitTransactionCanceled: return .persistentTransManagerSubmitTransactionCanceled
        case .persistentTransManagerSubmitTransactionRawDataMissing: return .persistentTransManagerSubmitTransactionRawDataMissing
        case .persistentTransManagerSubmitFailed: return .persistentTransManagerSubmitFailed
        case .persistentTransManagerApplyMinedHeightTransactionIDMissing: return .persistentTransManagerApplyMinedHeightTransactionIDMissing
        case .persistentTransManagerApplyMinedHeightTransactionNotFound: return .persistentTransManagerApplyMinedHeightTransactionNotFound
        case .zatoshiDecode: return .zatoshiDecode
        case .zatoshiEncode: return .zatoshiEncode
        case .unspentTransactionFetcherStream: return .unspentTransactionFetcherStream
        case .compactBlockProcessorInvalidConfiguration: return .compactBlockProcessorInvalidConfiguration
        case .compactBlockProcessorMissingDbPath: return .compactBlockProcessorMissingDbPath
        case .compactBlockProcessorDataDbInitFailed: return .compactBlockProcessorDataDbInitFailed
        case .compactBlockProcessorConnection: return .compactBlockProcessorConnection
        case .compactBlockProcessorGrpcError: return .compactBlockProcessorGrpcError
        case .compactBlockProcessorConnectionTimeout: return .compactBlockProcessorConnectionTimeout
        case .compactBlockProcessorMaxAttemptsReached: return .compactBlockProcessorMaxAttemptsReached
        case .compactBlockProcessorUnspecified: return .compactBlockProcessorUnspecified
        case .compactBlockProcessorCritical: return .compactBlockProcessorCritical
        case .compactBlockProcessorInvalidAccount: return .compactBlockProcessorInvalidAccount
        case .compactBlockProcessorWrongConsensusBranchId: return .compactBlockProcessorWrongConsensusBranchId
        case .compactBlockProcessorNetworkMismatch: return .compactBlockProcessorNetworkMismatch
        case .compactBlockProcessorSaplingActivationMismatch: return .compactBlockProcessorSaplingActivationMismatch
        case .compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL: return .compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL
        case .compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb: return .compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb
        case .compactBlockProcessorChainName: return .compactBlockProcessorChainName
        case .compactBlockProcessorConsensusBranchID: return .compactBlockProcessorConsensusBranchID
        case .synchronizerNotPrepared: return .synchronizerNotPrepared
        case .synchronizerSendMemoToTransparentAddress: return .synchronizerSendMemoToTransparentAddress
        case .synchronizerShieldFundsInsuficientTransparentFunds: return .synchronizerShieldFundsInsuficientTransparentFunds
        case .synchronizerLatestUTXOsInvalidTAddress: return .synchronizerLatestUTXOsInvalidTAddress
        case .synchronizerRewindUnknownArchorHeight: return .synchronizerRewindUnknownArchorHeight
        }
    }

    public static func == (lhs: ZcashError, rhs: ZcashError) -> Bool {
        return lhs.code == rhs.code
    }
}
