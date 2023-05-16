//
//  CompactBlockEnhancement.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

protocol BlockEnhancer {
    func enhance(at range: CompactBlockRange, didEnhance: (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]?
}

struct BlockEnhancerImpl {
    let blockDownloaderService: BlockDownloaderService
    let internalSyncProgress: InternalSyncProgress
    let rustBackend: ZcashRustBackendWelding
    let transactionRepository: TransactionRepository
    let metrics: SDKMetrics
    let logger: Logger

    private func enhance(transaction: ZcashTransaction.Overview) async throws -> ZcashTransaction.Overview {
        logger.debug("Zoom.... Enhance... Tx: \(transaction.rawID.toHexStringTxId())")

        let fetchedTransaction = try await blockDownloaderService.fetchTransaction(txId: transaction.rawID)

        let transactionID = fetchedTransaction.rawID.toHexStringTxId()
        let block = String(describing: transaction.minedHeight)
        logger.debug("Decrypting and storing transaction id: \(transactionID) block: \(block)")

        try await rustBackend.decryptAndStoreTransaction(
            txBytes: fetchedTransaction.raw.bytes,
            minedHeight: Int32(fetchedTransaction.minedHeight)
        )

        return try await transactionRepository.find(rawID: fetchedTransaction.rawID)
    }
}

extension BlockEnhancerImpl: BlockEnhancer {
    func enhance(at range: CompactBlockRange, didEnhance: (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]? {
        try Task.checkCancellation()
        
        logger.debug("Started Enhancing range: \(range)")

        var retries = 0
        let maxRetries = 5
        
        // fetch transactions
        do {
            let startTime = Date()
            let transactions = try await transactionRepository.find(in: range, limit: Int.max, kind: .all)

            guard !transactions.isEmpty else {
                await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
                logger.debug("no transactions detected on range: \(range.lowerBound)...\(range.upperBound)")
                return nil
            }

            let chainTipHeight = try await blockDownloaderService.latestBlockHeight()

            let newlyMinedLowerBound = chainTipHeight - ZcashSDK.expiryOffset

            let newlyMinedRange = newlyMinedLowerBound...chainTipHeight

            for index in 0 ..< transactions.count {
                let transaction = transactions[index]
                var retry = true
                
                while retry && retries < maxRetries {
                    try Task.checkCancellation()
                    do {
                        let confirmedTx = try await enhance(transaction: transaction)
                        retry = false
                        
                        let progress = EnhancementProgress(
                            totalTransactions: transactions.count,
                            enhancedTransactions: index + 1,
                            lastFoundTransaction: confirmedTx,
                            range: range,
                            newlyMined: confirmedTx.isSentTransaction && newlyMinedRange.contains(confirmedTx.minedHeight ?? 0)
                        )

                        await didEnhance(progress)

                        if let minedHeight = confirmedTx.minedHeight {
                            await internalSyncProgress.set(minedHeight, .latestEnhancedHeight)
                        }
                    } catch {
                        retries += 1
                        logger.error("could not enhance txId \(transaction.rawID.toHexStringTxId()) - Error: \(error)")
                        if retries > maxRetries {
                            throw error
                        }
                    }
                }
            }
            
            metrics.pushProgressReport(
                progress: BlockProgress(
                    startHeight: range.lowerBound,
                    targetHeight: range.upperBound,
                    progressHeight: range.upperBound
                ),
                start: startTime,
                end: Date(),
                batchSize: range.count,
                operation: .enhancement
            )
        } catch {
            logger.error("error enhancing transactions! \(error)")
            throw error
        }

        await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
        
        if Task.isCancelled {
            logger.debug("Warning: compactBlockEnhancement on range \(range) cancelled")
        }

        return (try? await transactionRepository.find(in: range, limit: Int.max, kind: .all))
    }
}
