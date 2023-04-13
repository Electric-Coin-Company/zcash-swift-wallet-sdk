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

protocol BlockValidator {
    /// Validate all the downloaded blocks that haven't been yet validated.
    func validate() async throws
}

struct BlockValidatorImpl {
    let rustBackend: ZcashRustBackendWelding
    let metrics: SDKMetrics
    let logger: Logger
}

extension BlockValidatorImpl: BlockValidator {
    func validate() async throws {
        try Task.checkCancellation()

        let startTime = Date()
        do {
            try await rustBackend.validateCombinedChain(limit: 0)
            pushProgressReport(startTime: startTime, finishTime: Date())
            logger.debug("validateChainFinished")
        } catch {
            pushProgressReport(startTime: startTime, finishTime: Date())

            switch error {
            case let ZcashError.rustValidateCombinedChainInvalidChain(upperBound):
                throw BlockValidatorError.validationFailed(height: BlockHeight(upperBound))

            default:
                throw BlockValidatorError.failedWithError(error)
            }
        }
    }

    private func pushProgressReport(startTime: Date, finishTime: Date) {
        metrics.pushProgressReport(
            progress: BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0),
            start: startTime,
            end: finishTime,
            batchSize: 0,
            operation: .validateBlocks
        )
    }
}
