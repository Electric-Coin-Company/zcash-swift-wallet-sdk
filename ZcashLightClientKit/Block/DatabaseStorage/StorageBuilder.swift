//
//  StorageBuilder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/14/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite
struct StorageBuilder {
    
    static func cacheDb(at url: URL) -> Storage? {
        do {
            let connection = try Connection(url.absoluteString)
            let blockDAO = CompactBlockStorage(connection: connection)
            try blockDAO.createTable()
            return SQLiteStorage(connection: connection, compactBlockDAO: blockDAO)
            
        } catch {
            return nil
        }
    }
}
