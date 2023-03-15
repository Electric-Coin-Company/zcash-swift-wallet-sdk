//
//  CompactBlockEnhancement.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

enum BlockEnhancerError: Error {
    case noRawData(message: String)
    case unknownError
    case decryptError(error: Error)
    case txIdNotFound(txId: Data)
}

struct BlockEnhancerConfig {
    let dataDb: URL
    let networkType: NetworkType
}

protocol BlockEnhancer {
    func enhance(at range: CompactBlockRange, didEnhance: (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]
}

struct BlockEnhancerImpl {
    let blockDownloaderService: BlockDownloaderService
    let config: BlockEnhancerConfig
    let internalSyncProgress: InternalSyncProgress
    let rustBackend: ZcashRustBackendWelding.Type
    let transactionRepository: TransactionRepository

    private func enhance(transaction: ZcashTransaction.Overview) async throws -> ZcashTransaction.Overview {
        LoggerProxy.debug("Zoom.... Enhance... Tx: \(transaction.rawID.toHexStringTxId())")

        let fetchedTransaction = try await blockDownloaderService.fetchTransaction(txId: transaction.rawID)

        let transactionID = fetchedTransaction.rawID.toHexStringTxId()
        let block = String(describing: transaction.minedHeight)
        LoggerProxy.debug("Decrypting and storing transaction id: \(transactionID) block: \(block)")

        let decryptionResult = rustBackend.decryptAndStoreTransaction(
            dbData: config.dataDb,
            txBytes: fetchedTransaction.raw.bytes,
            minedHeight: Int32(fetchedTransaction.minedHeight),
            networkType: config.networkType
        )

        guard decryptionResult else {
            throw BlockEnhancerError.decryptError(
                error: rustBackend.lastError() ?? .genericError(message: "`decryptAndStoreTransaction` failed. No message available")
            )
        }

        let confirmedTx: ZcashTransaction.Overview
        do {
            confirmedTx = try transactionRepository.find(rawID: fetchedTransaction.rawID)
        } catch {
            if let err = error as? TransactionRepositoryError, case .notFound = err {
                throw BlockEnhancerError.txIdNotFound(txId: fetchedTransaction.rawID)
            } else {
                throw error
            }
        }

        return confirmedTx
    }
}

extension BlockEnhancerImpl: BlockEnhancer {
    enum EnhancementError: Error {
        case noRawData(message: String)
        case unknownError
        case decryptError(error: Error)
        case txIdNotFound(txId: Data)
    }

    func enhance(at range: CompactBlockRange, didEnhance: (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview] {
        try Task.checkCancellation()
        
        LoggerProxy.debug("Started Enhancing range: \(range)")

        var retries = 0
        let maxRetries = 5
        
        // fetch transactions
        do {
            let startTime = Date()
            let transactions = try transactionRepository.find(in: range, limit: Int.max, kind: .all)

            guard !transactions.isEmpty else {
                await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
                LoggerProxy.debug("no transactions detected on range: \(range.lowerBound)...\(range.upperBound)")
                return []
            }
            
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
                            range: range
                        )
                        await didEnhance(progress)

                        if let minedHeight = confirmedTx.minedHeight {
                            await internalSyncProgress.set(minedHeight, .latestEnhancedHeight)
                        }
                    } catch {
                        retries += 1
                        LoggerProxy.error("could not enhance txId \(transaction.rawID.toHexStringTxId()) - Error: \(error)")
                        if retries > maxRetries {
                            throw error
                        }
                    }
                }
            }
            
            SDKMetrics.shared.pushProgressReport(
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
            LoggerProxy.error("error enhancing transactions! \(error)")
            throw error
        }

        await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
        
        if Task.isCancelled {
            LoggerProxy.debug("Warning: compactBlockEnhancement on range \(range) cancelled")
        }

        return (try? transactionRepository.find(in: range, limit: Int.max, kind: .all)) ?? []
    }
}
