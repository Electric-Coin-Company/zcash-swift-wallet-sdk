// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

/*
!!!!! To edit this file go to ZcashErrorCodeDefinition first and udate/add codes. Then run generateErrorCode.sh script to regenerate this file.

By design each error code should be used only at one place in the app. Thanks to that it is possible to identify exact line in the code from which the
error originates. And it can help with debugging.
*/

public enum ZcashErrorCode: String {
    /// Some testing code for now. Will be removed later.
    /// Some multiline super doc:
    /// - message - Message associated with error
    /// - code - Code for error.
    /// - error - underlying error
    case testCodeWithMessage = "ZTEST0001"
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
}
