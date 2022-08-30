//
//  CompactBlockValidationInformation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/30/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum CompactBlockValidationError: Error {
    case validationFailed(height: BlockHeight)
    case failedWithError(_ error: Error?)
}
class CompactBlockValidationOperation: ZcashOperation {
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    
    private var cacheDb: URL
    private var dataDb: URL
    private var network: NetworkType
    private var cancelableTask: Task<Void, Error>?
    private var done = false

    init(
        rustWelding: ZcashRustBackendWelding.Type,
        cacheDb: URL,
        dataDb: URL,
        networkType: NetworkType
    ) {
        rustBackend = rustWelding
        self.cacheDb = cacheDb
        self.dataDb = dataDb
        self.network = networkType
        super.init()
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }

        self.startedHandler?()

        cancelableTask = Task {
            let result = self.rustBackend.validateCombinedChain(dbCache: cacheDb, dbData: dataDb, networkType: self.network)
            
            switch result {
            case 0:
                let error = CompactBlockValidationError.failedWithError(rustBackend.lastError())
                self.error = error
                LoggerProxy.debug("block scanning failed with error: \(String(describing: self.error))")
                self.fail(error: error)
                
            case ZcashRustBackendWeldingConstants.validChain:
                self.done = true
                break
                
            default:
                let error = CompactBlockValidationError.validationFailed(height: BlockHeight(result))
                self.error = error
                LoggerProxy.debug("block scanning failed with error: \(String(describing: self.error))")
                self.fail(error: error)
            }
        }
        
        while !done && !isCancelled {
            sleep(1)
        }
    }
    
    override func fail(error: Error? = nil) {
        self.cancelableTask?.cancel()
        super.fail(error: error)
    }
    
    override func cancel() {
        self.cancelableTask?.cancel()
        super.cancel()
    }
}
