// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

/*
!!!!! To edit this file go to ZcashErrorCodeDefinition first and udate/add codes. Then run generateErrorCode.sh script to regenerate this file.

By design each error should be used only at one place in the app. Thanks to that it is possible to identify exact line in the code from which the
error originates. And it can help with debugging.
*/

import Foundation

public enum ZcashError: Equatable, Error {
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

    public var message: String {
        switch self {
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
        }
    }

    public var code: ZcashErrorCode {
        switch self {
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
        }
    }

    public static func == (lhs: ZcashError, rhs: ZcashError) -> Bool {
        return lhs.code == rhs.code
    }
}
