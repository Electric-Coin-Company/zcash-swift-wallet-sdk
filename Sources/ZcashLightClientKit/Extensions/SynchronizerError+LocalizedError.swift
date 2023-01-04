//
//  SynchronizerError+LocalizedError.swift
//  
//
//  Created by Francisco Gindre on 7/11/22.
//

import Foundation

extension SynchronizerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .initFailed(message: let message):
            return "Failed to initialize. Message: \(message)"
        case .notPrepared:
            return "Synchronizer is not prepared. run `prepare()` before `start()"
        case .syncFailed:
            return "Synchronizer failed"
        case .connectionFailed(message: let message):
            return "Connection Failed. Error: \(message)"
        case .generalError(message: let message):
            return "An error occurred when syncing. Message: \(message)"
        case .maxRetryAttemptsReached(attempts: let attempts):
            return "An error occurred. We made \(attempts) retry attempts."
        case .connectionError(status: let status, message: let message):
            return "There's a connection error. Status #\(status). Message: \(message)"
        case .networkTimeout:
            return "Network Timeout. Please check Internet connection"
        case .uncategorized(underlyingError: let underlyingError):
            return "Uncategorized Error. Underlying Error: \(underlyingError)"
        case .criticalError:
            return "A critical Error Occurred"
        case .parameterMissing(underlyingError: let underlyingError):
            return "Sapling parameters are not present or couldn't be downloaded. Error: \(underlyingError)."
        case .rewindError(underlyingError: let underlyingError):
            return "Error when rescanning. Error: \(underlyingError)"
        case .rewindErrorUnknownArchorHeight:
            return "Error when rescanning. We couldn't find a point in time to rewind. Please attempt a full re-scan"
        case .invalidAccount:
            return "We couldn't find this account number."
        case .lightwalletdValidationFailed(underlyingError: let underlyingError):
            return "We connected to the network but we couldn't verify the server. `lightwalletdValidationFailed` error: \(underlyingError)."
        }
    }
}
