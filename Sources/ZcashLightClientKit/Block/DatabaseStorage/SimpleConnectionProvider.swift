//
//  SimpleConnectionProvider.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

class SimpleConnectionProvider: ConnectionProvider {
    var path: String
    var readonly: Bool
    var db: Connection?
    
    init(path: String, readonly: Bool = false) {
        self.path = path
        self.readonly = readonly
    }

    /// throws ZcashError.simpleConnectionProvider
    func connection() throws -> Connection {
        guard let conn = db else {
            do {
                let conn = try Connection(path, readonly: readonly)
                self.db = conn
                return conn
            } catch {
                throw ZcashError.simpleConnectionProvider(error)
            }
        }
        return conn
    }

    func close() {
        self.db = nil
    }
}
