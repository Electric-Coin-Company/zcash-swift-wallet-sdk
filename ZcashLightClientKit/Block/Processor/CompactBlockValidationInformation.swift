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
}
class CompactBlockValidationOperation: ZcashOperation {
    
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    
    private var cacheDb: URL
    private var dataDb: URL
    
    init(rustWelding: ZcashRustBackendWelding.Type, cacheDb: URL, dataDb: URL) {
        rustBackend = rustWelding
        self.cacheDb = cacheDb
        self.dataDb = dataDb
        super.init()
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        
        let result = self.rustBackend.validateCombinedChain(dbCache: cacheDb, dbData: dataDb)
        if result != ZcashRustBackendWeldingConstants.validChain {
            
            let error = CompactBlockValidationError.validationFailed(height: BlockHeight(result))
            self.error = error
            LoggerProxy.debug("block scanning failed with error: \(String(describing: self.error))")
            self.fail(error: error)
            return
        }
    }
}
