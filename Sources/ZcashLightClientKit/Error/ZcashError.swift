// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

/*
!!!!! To edit this file go to ZcashErrorCodeDefinition first and udate/add codes. Then run generateErrorCode.sh script to regenerate this file.

By design each error should be used only at one place in the app. Thanks to that it is possible to identify exact line in the code from which the
error originates. And it can help with debugging.
*/

public enum ZcashError: Equatable, Error {
    /// Some testing code for now. Will be removed later.
    /// Some multiline super doc:
    /// - code - Code for error.
    /// - error - underlying error
    /// ZTEST0001
    case testCodeWithMessage(_ code: Int, _ error: Error)
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

    public var message: String {
        switch self {
        case .testCodeWithMessage: return "Some testing code for now. Will be removed later."
        case .serviceUnknownError: return "Unknown GRPC Service error"
        case .serviceGetInfoFailed: return "LightWalletService.getInfo failed."
        case .serviceLatestBlockFailed: return "LightWalletService.latestBlock failed."
        case .serviceLatestBlockHeightFailed: return "LightWalletService.latestBlockHeight failed."
        case .serviceBlockRangeFailed: return "LightWalletService.blockRange failed."
        case .serviceSubmitFailed: return "LightWalletService.submit failed."
        case .serviceFetchTransactionFailed: return "LightWalletService.fetchTransaction failed."
        case .serviceFetchUTXOsFailed: return "LightWalletService.fetchUTXOs failed."
        case .serviceBlockStreamFailed: return "LightWalletService.blockStream failed."
        }
    }

    public var code: ZcashErrorCode {
        switch self {
        case .testCodeWithMessage: return .testCodeWithMessage
        case .serviceUnknownError: return .serviceUnknownError
        case .serviceGetInfoFailed: return .serviceGetInfoFailed
        case .serviceLatestBlockFailed: return .serviceLatestBlockFailed
        case .serviceLatestBlockHeightFailed: return .serviceLatestBlockHeightFailed
        case .serviceBlockRangeFailed: return .serviceBlockRangeFailed
        case .serviceSubmitFailed: return .serviceSubmitFailed
        case .serviceFetchTransactionFailed: return .serviceFetchTransactionFailed
        case .serviceFetchUTXOsFailed: return .serviceFetchUTXOsFailed
        case .serviceBlockStreamFailed: return .serviceBlockStreamFailed
        }
    }

    public static func == (lhs: ZcashError, rhs: ZcashError) -> Bool {
        return lhs.code == rhs.code
    }
}
