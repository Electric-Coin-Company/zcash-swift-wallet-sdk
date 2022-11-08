//
//  SQLDatabase.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

class StorageManager {
    static var shared = StorageManager()
    
    private var readOnly: [URL: Connection] = [:]
    private var readWrite: [URL: Connection] = [:]
    
    init() {}
    
    func connection(at url: URL, readOnly: Bool = false) throws -> Connection {
        readOnly ? try readOnlyConnection(at: url) : try readWriteConnection(at: url)
    }
    
    private func readOnlyConnection(at url: URL) throws -> Connection {
        if let readOnlyConnection = readOnly[url] {
            return readOnlyConnection
        }
        
        let readOnlyConnection = try Connection.customConection(at: url)
        readOnly[url] = readOnlyConnection

        return readOnlyConnection
    }
    
    private func readWriteConnection(at url: URL) throws -> Connection {
        if let readWriteConnection = readWrite[url] {
            return readWriteConnection
        }
        
        let readWriteConnection = try Connection.customConection(at: url)
        readWrite[url] = readWriteConnection

        return readWriteConnection
    }
}

private extension Connection {
    static func customConection(at url: URL, readonly: Bool = false) throws -> Connection {
        let conn = try Connection(url.absoluteString, readonly: readonly)
        try conn.run("PRAGMA journal_mode = TRUNCATE;")
        return conn
    }
}

class SimpleConnectionProvider: ConnectionProvider {
    var path: String
    var readonly: Bool
    var db: Connection?
    
    init(path: String, readonly: Bool = false) {
        self.path = path
        self.readonly = readonly
    }

    func connection() throws -> Connection {
        guard let conn = db else {
            let conn = try Connection(path, readonly: readonly)
            self.db = conn
            return conn
        }
        return conn
    }

    func close() {
        self.db = nil
    }
}
