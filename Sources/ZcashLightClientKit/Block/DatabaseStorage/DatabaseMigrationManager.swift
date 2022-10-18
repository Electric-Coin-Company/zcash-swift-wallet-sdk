//
//  DatabaseMigrationManager.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 3/31/21.
//

import Foundation
import SQLite

class MigrationManager {
    enum CacheDbMigration: Int32, CaseIterable {
        case none = 0
    }

    enum PendingDbMigration: Int32, CaseIterable {
        case none = 0
        case v1 = 1
        case v2 = 2
    }

    static let latestCacheDbMigration: CacheDbMigration = CacheDbMigration.none
    static let latestPendingDbMigration: PendingDbMigration = PendingDbMigration.v1

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
            "Latest version is: \(Self.latestPendingDbMigration.rawValue - 1)"
        )

        for v in (currentPendingDbVersion...Self.latestPendingDbMigration.rawValue) {
            switch PendingDbMigration(rawValue: v) {
            case .some(.none):
                try migratePendingDbV1()
            case .some(.v1):
                try migratePendingDbV2()
            case .some(.v2):
                break
            case nil:
                throw StorageError.migrationFailedWithMessage(message: "Invalid migration version: \(v).")
            }
        }
    }

    func migratePendingDbV1() throws {
        let statement = PendingTransactionSQLDAO.table.create(ifNotExists: true) { createdTable in
            createdTable.column(PendingTransactionSQLDAO.TableColumns.id, primaryKey: .autoincrement)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.toAddress)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.accountIndex)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.minedHeight)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.expiryHeight)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.cancelled)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.encodeAttempts, defaultValue: 0)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.errorMessage)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.errorCode)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.submitAttempts, defaultValue: 0)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.createTime)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.rawTransactionId)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.value)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.raw)
            createdTable.column(PendingTransactionSQLDAO.TableColumns.memo)
        }

        try pendingDb.connection().transaction {
            try pendingDb.connection().run(statement);
            try self.pendingDb.connection().setUserVersion(PendingDbMigration.v1.rawValue);
        }
    }

    func migratePendingDbV2() throws {
        let statement =
            """
            ALTER TABLE pending_transactions RENAME TO pending_transactions_old;

            CREATE TABLE pending_transactions(
                id              INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                to_address      TEXT,
                to_internal     INTEGER,
                account_index   INTEGER NOT NULL,
                mined_height    INTEGER,
                expiry_height   INTEGER,
                cancelled       INTEGER,
                encode_attempts INTEGER DEFAULT (0),
                error_message   TEXT,
                error_code      INTEGER,
                submit_attempts INTEGER DEFAULT (0),
                create_time     REAL,
                txid            BLOB,
                value           INTEGER NOT NULL,
                raw             BLOB,
                memo            BLOB
            );

            INSERT INTO pending_transactions
            SELECT
                id,
                to_address,
                NULL,
                account_index,
                mined_height,
                expiry_height,
                cancelled,
                encode_attempts,
                error_message,
                error_code,
                submit_attempts,
                create_time,
                txid,
                value,
                raw,
                memo
            FROM pending_transactions_old;
            """

        try pendingDb.connection().transaction {
            try pendingDb.connection().run(statement);
            try self.pendingDb.connection().setUserVersion(PendingDbMigration.v2.rawValue);
        }
    }

    func migrateCacheDb() throws {
        let currentCacheDbVersion = try cacheDb.connection().getUserVersion()

        LoggerProxy.debug(
            "Attempting to perform migration for cache Db - currentVersion: \(currentCacheDbVersion)." +
            "Latest version is: \(Self.latestCacheDbMigration.rawValue)"
        )

        if currentCacheDbVersion < Self.latestCacheDbMigration.rawValue {
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
