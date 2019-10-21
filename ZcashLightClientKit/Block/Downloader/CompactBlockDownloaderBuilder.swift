//
//  CompactBlockDownloaderBuilder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/18/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

extension CompactBlockDownloader {
    static func sqlDownloader(service: LightWalletService, at url: URL) -> CompactBlockDownloader? {
        
        let storage = CompactBlockStorage(connectionProvider: SimpleConnectionProvider(path: url.absoluteString, readonly: false))
        
        guard (try? storage.createTable()) != nil else { return nil }
        
        return CompactBlockDownloader(service: service, storage: storage)
    }
}
