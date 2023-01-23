//
//  CompactBlockEnhancement.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

extension CompactBlockProcessor {
    enum EnhancementError: Error {
        case noRawData(message: String)
        case unknownError
        case decryptError(error: Error)
        case txIdNotFound(txId: Data)
    }
    
    private func enhance(transaction: ZcashTransaction.Overview) async throws -> ZcashTransaction.Overview {
        LoggerProxy.debug("Zoom.... Enhance... Tx: \(transaction.rawID.toHexStringTxId())")
        
        let fetchedTransaction = try await downloader.fetchTransaction(txId: transaction.rawID)

        let transactionID = fetchedTransaction.rawID.toHexStringTxId()
        let block = String(describing: transaction.minedHeight)
        LoggerProxy.debug("Decrypting and storing transaction id: \(transactionID) block: \(block)")
        
        let decryptionResult = rustBackend.decryptAndStoreTransaction(
            dbData: config.dataDb,
            txBytes: fetchedTransaction.raw.bytes,
            minedHeight: Int32(fetchedTransaction.minedHeight),
            networkType: config.network.networkType
        )

        guard decryptionResult else {
            throw EnhancementError.decryptError(
                error: rustBackend.lastError() ?? .genericError(message: "`decryptAndStoreTransaction` failed. No message available")
            )
        }

        let confirmedTx: ZcashTransaction.Overview
        do {
            confirmedTx = try transactionRepository.find(rawID: fetchedTransaction.rawID)
        } catch {
            if let err = error as? TransactionRepositoryError, case .notFound = err {
                throw EnhancementError.txIdNotFound(txId: fetchedTransaction.rawID)
            } else {
                throw error
            }
        }

        return confirmedTx
    }
    
    func compactBlockEnhancement(range: CompactBlockRange) async throws {
        try Task.checkCancellation()
        
        LoggerProxy.debug("Started Enhancing range: \(range)")
        state = .enhancing

        let blockRange = range.blockRange()
        var retries = 0
        let maxRetries = 5
        
        // fetch transactions
        do {
            let startTime = Date()
            let transactions = try transactionRepository.find(in: blockRange, limit: Int.max, kind: .all)

            guard !transactions.isEmpty else {
                await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
                LoggerProxy.debug("no transactions detected on range: \(blockRange.printRange)")
                return
            }
            
            for index in 0 ..< transactions.count {
                let transaction = transactions[index]
                var retry = true
                
                while retry && retries < maxRetries {
                    try Task.checkCancellation()
                    do {
                        let confirmedTx = try await enhance(transaction: transaction)
                        retry = false
                        notifyProgress(
                            .enhance(
                                EnhancementStreamProgress(
                                    totalTransactions: transactions.count,
                                    enhancedTransactions: index + 1,
                                    lastFoundTransaction: confirmedTx,
                                    range: range
                                )
                            )
                        )

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

        if let foundTxs = try? transactionRepository.find(in: blockRange, limit: Int.max, kind: .all) {
            notifyTransactions(foundTxs, in: blockRange)
        }

        await internalSyncProgress.set(range.upperBound, .latestEnhancedHeight)
        
        if Task.isCancelled {
            LoggerProxy.debug("Warning: compactBlockEnhancement on range \(range) cancelled")
        }
    }
}

private extension BlockRange {
    var printRange: String {
        "\(self.start.height) ... \(self.end.height)"
    }
}
