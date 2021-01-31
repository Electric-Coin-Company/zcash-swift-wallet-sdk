//
//  CompactBlockProcessingOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class CompactBlockScanningOperation: ZcashOperation {
    
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    
    private var cacheDb: URL
    private var dataDb: URL
    private var chainNetwork: String
    init(rustWelding: ZcashRustBackendWelding.Type, cacheDb: URL, dataDb: URL, chainNetwork: String) {
        rustBackend = rustWelding
        self.cacheDb = cacheDb
        self.dataDb = dataDb
        self.chainNetwork = chainNetwork
        super.init()
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        guard self.rustBackend.scanBlocks(dbCache: self.cacheDb, dbData: self.dataDb, chainNetwork: self.chainNetwork) else {
            self.error = self.rustBackend.lastError() ?? ZcashOperationError.unknown
            LoggerProxy.debug("block scanning failed with error: \(String(describing: self.error))")
            self.fail()
            return
        }
    }
}
