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
    
    private func enhance(transaction: TransactionEntity) async throws -> ConfirmedTransactionEntity {
        LoggerProxy.debug("Zoom.... Enhance... Tx: \(transaction.transactionId.toHexStringTxId())")
        
        let transaction = try await downloader.fetchTransaction(txId: transaction.transactionId)

        let transactionID = transaction.transactionId.toHexStringTxId()
        let block = String(describing: transaction.minedHeight)
        LoggerProxy.debug("Decrypting and storing transaction id: \(transactionID) block: \(block)")
        
        guard let rawBytes = transaction.raw?.bytes else {
            let error = EnhancementError.noRawData(
                message: "Critical Error: transaction id: \(transaction.transactionId.toHexStringTxId()) has no data"
            )
            LoggerProxy.error("\(error)")
            throw error
        }
        
        guard let minedHeight = transaction.minedHeight else {
            let error = EnhancementError.noRawData(
                message: "Critical Error - Attempt to decrypt and store an unmined transaction. Id: \(transaction.transactionId.toHexStringTxId())"
            )
            LoggerProxy.error("\(error)")
            throw error
        }
        
        guard rustBackend.decryptAndStoreTransaction(dbData: config.dataDb, txBytes: rawBytes, minedHeight: Int32(minedHeight), networkType: config.network.networkType) else {
            throw EnhancementError.decryptError(
                error: rustBackend.lastError() ?? .genericError(message: "`decryptAndStoreTransaction` failed. No message available")
            )
        }
        
        guard let confirmedTx = try transactionRepository.findConfirmedTransactionBy(rawId: transaction.transactionId) else {
            throw EnhancementError.txIdNotFound(txId: transaction.transactionId)
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
            guard let transactions = try transactionRepository.findTransactions(in: blockRange, limit: Int.max), !transactions.isEmpty else {
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
                        await internalSyncProgress.set(confirmedTx.minedHeight, .latestEnhancedHeight)

                    } catch {
                        retries += 1
                        LoggerProxy.error("could not enhance txId \(transaction.transactionId.toHexStringTxId()) - Error: \(error)")
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
        
        if let foundTxs = try? transactionRepository.findConfirmedTransactions(in: blockRange, offset: 0, limit: Int.max) {
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
