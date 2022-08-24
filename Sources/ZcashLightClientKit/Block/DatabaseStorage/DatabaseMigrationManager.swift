//
//  DatabaseMigrationManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 3/31/21.
//

import Foundation
import SQLite

class MigrationManager {
    enum CacheDbMigration: Int32 {
        case none = 0
    }
    
    enum PendingDbMigration: Int32 {
        case none = 0
    }

    static let latestCacheDbMigrationVersion: Int32 = CacheDbMigration.none.rawValue
    static let latestPendingDbMigrationVersion: Int32 = PendingDbMigration.none.rawValue
    
    var cacheDb: ConnectionProvider
    var pendingDb: ConnectionProvider
    var network: NetworkType

    init(
        cacheDbConnection: ConnectionProvider,
        pendingDbConnection: ConnectionProvider,
        networkType: NetworkType
    ) {
        self.cacheDb = cacheDbConnection
        self.pendingDb = pendingDbConnection
        self.network = networkType
    }

    func performMigration(ufvks: [UnifiedFullViewingKey]) throws {
        try migrateCacheDb()
        try migratePendingDb()
    }
}

private extension MigrationManager {
    func migratePendingDb() throws {
        let currentPendingDbVersion = try pendingDb.connection().getUserVersion()

        LoggerProxy.debug(
            "Attempting to perform migration for pending Db - currentVersion: \(currentPendingDbVersion)." +
            "Latest version is: \(Self.latestPendingDbMigrationVersion)"
        )

        if currentPendingDbVersion < Self.latestPendingDbMigrationVersion {
            // perform no migration just adjust the version number
            try self.cacheDb.connection().setUserVersion(PendingDbMigration.none.rawValue)
        } else {
            LoggerProxy.debug("PendingDb Db - no migration needed")
        }
    }

    func migrateCacheDb() throws {
        let currentCacheDbVersion = try cacheDb.connection().getUserVersion()

        LoggerProxy.debug(
            "Attempting to perform migration for cache Db - currentVersion: \(currentCacheDbVersion)." +
            "Latest version is: \(Self.latestCacheDbMigrationVersion)"
        )

        if currentCacheDbVersion < Self.latestCacheDbMigrationVersion {
            // perform no migration just adjust the version number
            try self.cacheDb.connection().setUserVersion(CacheDbMigration.none.rawValue)
        } else {
            LoggerProxy.debug("Cache Db - no migration needed")
        }
    }
}

extension Connection {
    func getUserVersion() throws -> Int32 {
        guard let version = try scalar("PRAGMA user_version") as? Int64 else {
            return 0
        }
        return Int32(version)
    }
    
    func setUserVersion(_ version: Int32) throws {
        try run("PRAGMA user_version = \(version)")
    }
}
