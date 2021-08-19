//
//  CompactBlockEnhancementOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

class CompactBlockEnhancementOperation: ZcashOperation {
    enum EnhancementError: Error {
        case noRawData(message: String)
        case unknownError
        case decryptError(error: Error)
        case txIdNotFound(txId: Data)
    }
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    var txFoundHandler: (([ConfirmedTransactionEntity], BlockRange) -> Void)?
    var downloader: CompactBlockDownloading
    var repository: TransactionRepository
    var maxRetries: Int = 5
    var retries: Int = 0
    private(set) var network: NetworkType
    weak var progressDelegate: CompactBlockProgressDelegate?
    private var dataDb: URL
    
    var range: BlockRange
    
    init(rustWelding: ZcashRustBackendWelding.Type,
         dataDb: URL,
         downloader: CompactBlockDownloading,
         repository: TransactionRepository,
         range: BlockRange,
         networkType: NetworkType,
         progressDelegate: CompactBlockProgressDelegate? = nil) {
        rustBackend = rustWelding
        self.dataDb = dataDb
        self.downloader = downloader
        self.repository = repository
        self.range = range
        self.progressDelegate = progressDelegate
        self.network = networkType
        super.init()
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        self.startedHandler?()
        // fetch transactions
        
        do {
            guard let transactions = try repository.findTransactions(in: self.range, limit: Int.max), transactions.count > 0 else {
                LoggerProxy.debug("no transactions detected on range: \(range.printRange)")
                return
            }
            
            for index in 0 ..< transactions.count {
                let tx = transactions[index]
                
                var retry = true
                while retry && self.retries < maxRetries {
                    do {
                        let confirmedTx = try enhance(transaction: tx)
                        retry = false
                        self.reportProgress(totalTransactions: transactions.count,
                                            enhanced: index + 1,
                                            txEnhanced: confirmedTx)
                    } catch {
                        self.retries = self.retries + 1
                        LoggerProxy.error("could not enhance txId \(tx.transactionId.toHexStringTxId()) - Error: \(error)")
                        if retries > maxRetries {
                            throw error
                        }
                    }
                }
            }
        } catch {
            LoggerProxy.error("error enhancing transactions! \(error)")
            self.error = error
            self.fail()
            return
        }
        
        if let handler = self.txFoundHandler, let foundTxs = try? repository.findConfirmedTransactions(in: self.range, offset: 0, limit: Int.max) {
            handler(foundTxs, self.range)
        }
    }
    
    func reportProgress(totalTransactions: Int, enhanced: Int, txEnhanced: ConfirmedTransactionEntity) {
        self.progressDelegate?.progressUpdated(.enhance(
                                                EnhancementStreamProgress(
                                                    totalTransactions: totalTransactions,
                                                    enhancedTransactions: enhanced,
                                                    lastFoundTransaction: txEnhanced,
                                                    range: self.range.compactBlockRange)))
    }
    
    func enhance(transaction: TransactionEntity) throws -> ConfirmedTransactionEntity {
        LoggerProxy.debug("Zoom.... Enhance... Tx: \(transaction.transactionId.toHexStringTxId())")
        
        let tx = try downloader.fetchTransaction(txId: transaction.transactionId)
        
        LoggerProxy.debug("Decrypting and storing transaction id: \(tx.transactionId.toHexStringTxId()) block: \(String(describing: tx.minedHeight))")
        
        guard let rawBytes = tx.raw?.bytes else {
            let error = EnhancementError.noRawData(message: "Critical Error: transaction id: \(tx.transactionId.toHexStringTxId()) has no data")
            LoggerProxy.error("\(error)")
            throw error
        }
        
        guard rustBackend.decryptAndStoreTransaction(dbData: dataDb, tx: rawBytes, networkType: network) else {
            if let rustError = rustBackend.lastError() {
                throw EnhancementError.decryptError(error: rustError)
            }
            throw EnhancementError.unknownError
        }
        guard let confirmedTx = try self.repository.findConfirmedTransactionBy(rawId: transaction.transactionId) else {
            throw EnhancementError.txIdNotFound(txId: transaction.transactionId)
        }
        return confirmedTx
    }
}

fileprivate extension BlockRange {
    var printRange: String {
        "\(self.start.height) ... \(self.end.height)"
    }
}
