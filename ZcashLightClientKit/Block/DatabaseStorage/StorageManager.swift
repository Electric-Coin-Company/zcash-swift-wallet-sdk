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
    
    static var shared: StorageManager = StorageManager()
    
    private var readOnly = [URL: Connection]()
    private var readWrite = [URL: Connection]()
    
    init() {}
    
    func connection(at url: URL, readOnly: Bool = false) throws -> Connection {
        readOnly ? try readOnlyConnection(at: url) : try readWriteConnection(at: url)
    }
    
    private func readOnlyConnection(at url: URL) throws -> Connection {
        if let rw = readOnly[url] {
            return rw
        }
        
        let rw = try Connection(url.absoluteString)
        readOnly[url] = rw
        return rw
        
    }
    
    private func readWriteConnection(at url: URL) throws -> Connection {
        if let rw = readWrite[url] {
            return rw
        }
        
        let rw = try Connection(url.absoluteString)
        readWrite[url] = rw
        return rw
    }
}

/**
 Set  schema version
 */
// TODO: define a better way to do this
//extension Connection {
//    public var userVersion: Int32 {
//        get { return Int32(try scalar("PRAGMA user_version") as Int64)}
//        set { try! run("PRAGMA user_version = \(newValue)")}
//    }
//}
