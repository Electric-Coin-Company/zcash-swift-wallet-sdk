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
    }
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    var txFoundHandler: (([ConfirmedTransactionEntity], BlockRange) -> Void)?
    var downloader: CompactBlockDownloading
    var repository: TransactionRepository
    var maxRetries: Int = 5
    var retries: Int = 0
    private var dataDb: URL
    
    var range: BlockRange
    
    init(rustWelding: ZcashRustBackendWelding.Type, dataDb: URL, downloader: CompactBlockDownloading, repository: TransactionRepository, range: BlockRange) {
        rustBackend = rustWelding
        self.dataDb = dataDb
        self.downloader = downloader
        self.repository = repository
        self.range = range
        super.init()
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        
        // fetch transactions
        
        do {
            guard let transactions = try repository.findTransactions(in: self.range, limit: Int.max), transactions.count > 0 else {
                LoggerProxy.debug("no transactions detected on range: \(range.printRange)")
                return
            }
            
            for tx in transactions {
                var retry = true
                while retry && self.retries < maxRetries {
                    do {
                        try enhance(transaction: tx)
                        retry = false
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
    
    func enhance(transaction: TransactionEntity) throws {
        LoggerProxy.debug("Zoom.... Enhance... Tx: \(transaction.transactionId.toHexStringTxId()) Block: \(String(describing: transaction.minedHeight))")
        
        let tx = try downloader.fetchTransaction(txId: transaction.transactionId)
        
        LoggerProxy.debug("Decrypting and storing transaction id: \(tx.transactionId.toHexStringTxId()) block: \(String(describing: tx.minedHeight))")
        
        guard let rawBytes = tx.raw?.bytes else {
            let error = EnhancementError.noRawData(message: "Critical Error: transaction id: \(tx.transactionId.toHexStringTxId()) has no data")
            LoggerProxy.error("\(error)")
            throw error
        }
        
        guard rustBackend.decryptAndStoreTransaction(dbData: dataDb, tx: rawBytes) else {
            if let rustError = rustBackend.lastError() {
                throw EnhancementError.decryptError(error: rustError)
            }
            throw EnhancementError.unknownError
        }
    }
}

fileprivate extension BlockRange {
    var printRange: String {
        "\(self.start.height) ... \(self.end.height)"
    }
}
