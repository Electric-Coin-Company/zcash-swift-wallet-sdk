//
//  CompactBlockEnhancement.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

public struct EnhancementProgress: Equatable {
    /// total transactions that were detected in the `range`
    public let totalTransactions: Int
    /// enhanced transactions so far
    public let enhancedTransactions: Int
    /// last found transaction
    public let lastFoundTransaction: ZcashTransaction.Overview?
    /// block range that's being enhanced
    public let range: CompactBlockRange
    /// whether this transaction can be considered `newly mined` and not part of the
    /// wallet catching up to stale and uneventful blocks.
    public let newlyMined: Bool

    public init(
        totalTransactions: Int,
        enhancedTransactions: Int,
        lastFoundTransaction: ZcashTransaction.Overview?,
        range: CompactBlockRange,
        newlyMined: Bool
    ) {
        self.totalTransactions = totalTransactions
        self.enhancedTransactions = enhancedTransactions
        self.lastFoundTransaction = lastFoundTransaction
        self.range = range
        self.newlyMined = newlyMined
    }

    public var progress: Float {
        totalTransactions > 0 ? Float(enhancedTransactions) / Float(totalTransactions) : 0
    }

    public static var zero: EnhancementProgress {
        EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0, newlyMined: false)
    }

    public static func == (lhs: EnhancementProgress, rhs: EnhancementProgress) -> Bool {
        return
            lhs.totalTransactions == rhs.totalTransactions &&
            lhs.enhancedTransactions == rhs.enhancedTransactions &&
            lhs.lastFoundTransaction?.rawID == rhs.lastFoundTransaction?.rawID &&
            lhs.range == rhs.range
    }
}

protocol BlockEnhancer {
    func enhance(at range: CompactBlockRange, didEnhance: @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]?
}

struct BlockEnhancerImpl {
    let blockDownloaderService: BlockDownloaderService
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
    func enhance(at range: CompactBlockRange, didEnhance: @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]? {
        try Task.checkCancellation()
        
        logger.debug("Started Enhancing range: \(range)")

        var retries = 0
        let maxRetries = 5
        
        // fetch transactions
        do {
            let startTime = Date()
            let transactions = try await transactionRepository.find(in: range, limit: Int.max, kind: .all)

            guard !transactions.isEmpty else {
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
                start: startTime,
                end: Date(),
                batchSize: range.count,
                operation: .enhancement
            )
        } catch {
            logger.error("error enhancing transactions! \(error)")
            throw error
        }
        
        if Task.isCancelled {
            logger.debug("Warning: compactBlockEnhancement on range \(range) cancelled")
        }

        return (try? await transactionRepository.find(in: range, limit: Int.max, kind: .all))
    }
}
