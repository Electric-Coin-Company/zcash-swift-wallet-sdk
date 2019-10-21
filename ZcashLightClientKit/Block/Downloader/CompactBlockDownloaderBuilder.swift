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
    static func sqlDownloader(service: LightWalletService, at URL: URL) -> CompactBlockDownloader? {
        
        guard let connection = try? StorageManager.shared.connection(at: URL, readOnly: false) else { return nil }
        
        let storage = CompactBlockStorage(connection: connection)
        guard (try? storage.createTable()) != nil else { return nil }
        
        return CompactBlockDownloader(service: service, storage: storage)
    }
}
