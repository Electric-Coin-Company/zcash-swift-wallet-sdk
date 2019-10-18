//
//  SQLDatabase.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite

class SQLiteStorage: Storage {
    
    private var connection: Connection
    var compactBlockDao: CompactBlockDAO
    
    init(connection: Connection, compactBlockDAO: CompactBlockDAO) {
        self.compactBlockDao = compactBlockDAO
        self.connection = connection
    }
    
    func open(at path: String) throws {
        do {
           connection = try Connection(path)
        } catch {
            throw StorageError.openFailed
        }
    }
    
    func createDatabase(at path: String) throws {
       try compactBlockDao.createTable()
    }
    
    func closeDatabase() {}
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
