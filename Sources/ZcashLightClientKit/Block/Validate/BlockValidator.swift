//
//  CompactBlockValidationInformation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/30/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum BlockValidatorError: Error {
    case validationFailed(height: BlockHeight)
    case failedWithError(_ error: Error)
    case failedWithUnknownError
}

struct BlockValidatorConfig {
    let fsBlockCacheRoot: URL
    let dataDB: URL
    let networkType: NetworkType
}

protocol BlockValidator {
    /// Validate all the downloaded blocks that haven't been yet validated.
    func validate() async throws
}

struct BlockValidatorImpl {
    let config: BlockValidatorConfig
    let rustBackend: ZcashRustBackendWelding.Type
    let metrics: SDKMetrics
}

extension BlockValidatorImpl: BlockValidator {
    func validate() async throws {
        try Task.checkCancellation()

        let startTime = Date()
        let result = rustBackend.validateCombinedChain(
            fsBlockDbRoot: config.fsBlockCacheRoot,
            dbData: config.dataDB,
            networkType: config.networkType,
            limit: 0
        )
        let finishTime = Date()

        metrics.pushProgressReport(
            progress: BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0),
            start: startTime,
            end: finishTime,
            batchSize: 0,
            operation: .validateBlocks
        )

        switch result {
        case 0:
            let rustError = rustBackend.lastError()
            LoggerProxy.debug("Block validation failed with error: \(String(describing: rustError))")
            if let rustError {
                throw BlockValidatorError.failedWithError(rustError)
            } else {
                throw BlockValidatorError.failedWithUnknownError
            }

        case ZcashRustBackendWeldingConstants.validChain:
            LoggerProxy.debug("validateChainFinished")
            return

        default:
            LoggerProxy.debug("Block validation failed at height: \(result)")
            throw BlockValidatorError.validationFailed(height: BlockHeight(result))
        }
    }
}
