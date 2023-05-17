//
//  CompactBlockValidationInformation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/30/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

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
    /// - Throws:
    ///  - `rustValidateCombinedChainValidationFailed` if there was an error during validation unrelated to chain validity.
    ///  - `rustValidateCombinedChainInvalidChain(upperBound)` if the combined chain is invalid. `upperBound` is the height of the highest invalid
    ///    block(on the assumption that the highest block in the cache database is correct).
    func validate() async throws {
        try Task.checkCancellation()

        let startTime = Date()
        do {
            try await rustBackend.validateCombinedChain(limit: 0)
            pushProgressReport(startTime: startTime, finishTime: Date())
            logger.debug("validateChainFinished")
        } catch {
            logger.debug("Validate chain failed with \(error)")
            pushProgressReport(startTime: startTime, finishTime: Date())
            throw error
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
