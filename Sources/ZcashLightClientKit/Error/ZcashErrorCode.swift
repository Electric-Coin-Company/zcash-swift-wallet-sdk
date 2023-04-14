// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

/*
!!!!! To edit this file go to ZcashErrorCodeDefinition first and udate/add codes. Then run generateErrorCode.sh script to regenerate this file.

By design each error code should be used only at one place in the app. Thanks to that it is possible to identify exact line in the code from which the
error originates. And it can help with debugging.
*/

public enum ZcashErrorCode: String {
    /// Unknown GRPC Service error
    case serviceUnknownError = "ZSRVC0001"
    /// LightWalletService.getInfo failed.
    case serviceGetInfoFailed = "ZSRVC0002"
    /// LightWalletService.latestBlock failed.
    case serviceLatestBlockFailed = "ZSRVC0003"
    /// LightWalletService.latestBlockHeight failed.
    case serviceLatestBlockHeightFailed = "ZSRVC0004"
    /// LightWalletService.blockRange failed.
    case serviceBlockRangeFailed = "ZSRVC0005"
    /// LightWalletService.submit failed.
    case serviceSubmitFailed = "ZSRVC0006"
    /// LightWalletService.fetchTransaction failed.
    case serviceFetchTransactionFailed = "ZSRVC0007"
    /// LightWalletService.fetchUTXOs failed.
    case serviceFetchUTXOsFailed = "ZSRVC0008"
    /// LightWalletService.blockStream failed.
    case serviceBlockStreamFailed = "ZSRVC0000"
    /// Migration of the pending DB failed because of unspecific reason.
    case dbMigrationGenericFailure = "ZDBMG0001"
    /// Migration of the pending DB failed because unknown version of the existing database.
    case dbMigrationInvalidVersion = "ZDBMG00002"
    /// Migration of the pending DB to version 1 failed.
    case dbMigrationV1 = "ZDBMG00003"
    /// Migration of the pending DB to version 2 failed.
    case dbMigrationV2 = "ZDBMG00004"
    /// SimpleConnectionProvider init of Connection failed.
    case simpleConnectionProvider = "ZSCPC0001"
    /// Downloaded file with sapling spending parameters isn't valid.
    case saplingParamsInvalidSpendParams = "ZSAPP0001"
    /// Downloaded file with sapling output parameters isn't valid.
    case saplingParamsInvalidOutputParams = "ZSAPP0002"
    /// Failed to download sapling parameters file
    /// - `error` is download error.
    /// - `downloadURL` is URL from which was file downloaded.
    case saplingParamsDownload = "ZSAPP0003"
    /// Failed to move sapling parameters file to final destination after download.
    /// - `error` is move error.
    /// - `downloadURL` is URL from which was file downloaded.
    /// - `destination` is filesystem URL pointing to location where downloaded file should be moved.
    case saplingParamsCantMoveDownloadedFile = "ZSAPP0004"
    /// SQLite query failed when fetching received notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case notesDAOReceivedCount = "ZNDAO0001"
    /// SQLite query failed when fetching received notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case notesDAOReceivedNote = "ZNDAO0002"
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    case notesDAOReceivedCantDecode = "ZNDAO0003"
    /// SQLite query failed when fetching sent notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case notesDAOSentCount = "ZNDAO0004"
    /// SQLite query failed when fetching sent notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case notesDAOSentNote = "ZNDAO0005"
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    case notesDAOSentCantDecode = "ZNDAO0006"
    /// SQLite query failed when fetching block information from database.
    /// - `sqliteError` is error produced by SQLite library.
    case blockDAOBlock = "ZBDAO0001"
    /// Fetched block information from DB but can't decode them.
    /// - `error` is decoding error.
    case blockDAOCantDecode = "ZBDAO0002"
    /// SQLite query failed when fetching height of the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case blockDAOLatestBlockHeight = "ZBDAO0003"
    /// SQLite query failed when fetching the latest block from the database.
    /// - `sqliteError` is error produced by SQLite library.
    case blockDAOLatestBlock = "ZBDAO0004"
    /// Fetched latesxt block information from DB but can't decode them.
    /// - `error` is decoding error.
    case blockDAOLatestBlockCantDecode = "ZBDAO0005"
}
