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
    /// Some testing code for now. Will be removed later.
    /// Some multiline super doc:
    /// - message - Message associated with error
    /// - code - Code for error.
    /// - error - underlying error
    // sourcery: code="ZTEST0001"
    case testCodeWithMessage(_ message: String, _ code: Int, _ error: Error)
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
}
