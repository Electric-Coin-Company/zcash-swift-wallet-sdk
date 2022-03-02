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
        let storage = CompactBlockStorage(url: url, readonly: false)
        
        guard (try? storage.createTable()) != nil else { return nil }
        
        return CompactBlockDownloader(service: service, storage: storage)
    }
}

extension CompactBlockStorage {
    convenience init(url: URL, readonly: Bool) {
        self.init(connectionProvider: SimpleConnectionProvider(path: url.absoluteString, readonly: readonly))
    }
}
