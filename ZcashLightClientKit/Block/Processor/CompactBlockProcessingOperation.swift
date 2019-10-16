//
//  CompactBlockProcessingOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/15/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class CompactBlockScanningOperation: Operation {
    
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    var rustBackend: ZcashRustBackendWelding.Type
    
    private var cacheDb: URL
    private var dataDb: URL
    init(rustWelding: ZcashRustBackendWelding.Type, cacheDb: URL, dataDb:URL) {
        self.rustBackend = rustWelding
        self.cacheDb = cacheDb
        self.dataDb = dataDb
    }
    
    override func main() {
        guard self.rustBackend.scanBlocks(dbCache: self.cacheDb, dbData: self.dataDb) else {
            print("block scanning failed")
            return
        }
    }
}
