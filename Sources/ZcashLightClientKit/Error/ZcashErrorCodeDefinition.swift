//
//  ZcashErrorDefinition.swift
//  
//
//  Created by Michal Fousek on 10.04.2023.
//

import Foundation

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

    /// Migration of the pending DB failed because of unspecific reason.
    // sourcery: code="ZDBMG0001"
    case dbMigrationGenericFailure(_ error: Error)
    /// Migration of the pending DB failed because unknown version of the existing database.
    // sourcery: code="ZDBMG00002"
    case dbMigrationInvalidVersion
    /// Migration of the pending DB to version 1 failed.
    // sourcery: code="ZDBMG00003"
    case dbMigrationV1(_ dbError: Error)
    /// Migration of the pending DB to version 2 failed.
    // sourcery: code="ZDBMG00004"
    case dbMigrationV2(_ dbError: Error)

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

    // MARK: - NotesDAO

    /// SQLite query failed when fetching received notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZNDAO0001"
    case notesDAOReceivedCount(_ sqliteError: Error)
    /// SQLite query failed when fetching received notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZNDAO0002"
    case notesDAOReceivedNote(_ sqliteError: Error)
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    // sourcery: code="ZNDAO0003"
    case notesDAOReceivedCantDecode(_ error: Error)
    /// SQLite query failed when fetching sent notes count from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZNDAO0004"
    case notesDAOSentCount(_ sqliteError: Error)
    /// SQLite query failed when fetching sent notes from the database.
    /// - `sqliteError` is error produced by SQLite library.
    // sourcery: code="ZNDAO0005"
    case notesDAOSentNote(_ sqliteError: Error)
    /// Fetched note from the SQLite but can't decode that.
    /// - `error` is decoding error.
    // sourcery: code="ZNDAO0006"
    case notesDAOSentCantDecode(_ error: Error)
}
