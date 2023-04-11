//
//  TestDbBuilder.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/14/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SQLite
@testable import ZcashLightClientKit

struct TestDbHandle {
    var originalDb: URL
    var readWriteDb: URL
    
    init(originalDb: URL) {
        self.originalDb = originalDb
        // avoid files clashing because crashing tests failed to remove previous ones by incrementally changing the filename
        self.readWriteDb = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                self.originalDb.lastPathComponent.appending("_\(Date().timeIntervalSince1970)")
            )
    }
    
    func setUp() throws {
        try FileManager.default.copyItem(at: originalDb, to: readWriteDb)
    }
    
    func dispose() {
        try? FileManager.default.removeItem(at: readWriteDb)
    }
    
    func connectionProvider(readwrite: Bool = true) -> ConnectionProvider {
        SimpleConnectionProvider(path: self.readWriteDb.absoluteString, readonly: !readwrite)
    }
}

// This requires reference semantics, an enum cannot be used
enum TestDbBuilder {
    enum TestBuilderError: Error {
        case generalError
    }
    
    static func pendingTransactionsDbURL() throws -> URL {
        try __documentsDirectory().appendingPathComponent("pending.db")
    }
    
    static func prePopulatedDataDbURL() -> URL? {
        Bundle.module.url(forResource: "test_data", withExtension: "db")
    }

    static func prePopulatedMainnetDataDbURL() -> URL? {
        Bundle.module.url(forResource: "darkside_data", withExtension: "db")
    }

    static func prePopulatedDarksideCacheDb() -> URL? {
        Bundle.module.url(forResource: "darkside_caches", withExtension: "db")
    }
    
    static func prepopulatedDataDbProvider(rustBackend: ZcashRustBackendWelding) async throws -> ConnectionProvider? {
        guard let url = prePopulatedMainnetDataDbURL() else { return nil }

        let provider = SimpleConnectionProvider(path: url.absoluteString, readonly: true)

        let initResult = try await rustBackend.initDataDb(seed: Environment.seedBytes)
        
        switch initResult {
        case .success: return provider
        case .seedRequired:
            throw DatabaseStorageError.migrationFailedWithMessage(message: "Seed value required to initialize the wallet database")
        }
    }
    
    static func transactionRepository(rustBackend: ZcashRustBackendWelding) async throws -> TransactionRepository? {
        guard let provider = try await prepopulatedDataDbProvider(rustBackend: rustBackend) else { return nil }
        
        return TransactionSQLDAO(dbProvider: provider)
    }
    
    static func sentNotesRepository(rustBackend: ZcashRustBackendWelding) async throws -> SentNotesRepository? {
        guard let provider = try await prepopulatedDataDbProvider(rustBackend: rustBackend) else { return nil }
        return SentNotesSQLDAO(dbProvider: provider)
    }
    
    static func receivedNotesRepository(rustBackend: ZcashRustBackendWelding) async throws -> ReceivedNoteRepository? {
        guard let provider = try await prepopulatedDataDbProvider(rustBackend: rustBackend) else { return nil }
        return ReceivedNotesSQLDAO(dbProvider: provider)
    }
        
    static func seed(db: CompactBlockRepository, with blockRange: CompactBlockRange) async throws {
        guard let blocks = StubBlockCreator.createBlockRange(blockRange) else {
            throw TestBuilderError.generalError
        }
        
        try await db.write(blocks: blocks)
    }
}

class InMemoryDbProvider: ConnectionProvider {
    var readonly: Bool
    var conn: Connection?

    init(readonly: Bool = false) throws {
        self.readonly = readonly
    }
    
    func connection() throws -> Connection {
        guard let conn else {
            let newConnection = try Connection(.inMemory, readonly: readonly)
            self.conn = newConnection
            return newConnection
        }
        return conn
    }

    func close() {
        self.conn = nil
    }
}

enum StubBlockCreator {
    static func createRandomBlockMeta() -> ZcashCompactBlock.Meta {
        ZcashCompactBlock.Meta(
            hash: randomData(ofLength: 32)!,
            time: UInt32(Date().timeIntervalSince1970),
            saplingOutputs: UInt32.random(in: 0 ... 32),
            orchardOutputs: UInt32.random(in: 0 ... 32)
        )
    }

    static func createRandomDataBlock(with height: BlockHeight) -> ZcashCompactBlock? {
        guard let data = randomData(ofLength: 100) else {
            LoggerProxy.debug("error creating stub block")
            return nil
        }
        return ZcashCompactBlock(height: height, data: data, meta: createRandomBlockMeta())
    }

    static func createBlockRange(_ range: CompactBlockRange) -> [ZcashCompactBlock]? {
        var blocks: [ZcashCompactBlock] = []
        for height in range {
            guard let block = createRandomDataBlock(with: height) else {
                return nil
            }
            blocks.append(block)
        }
        
        return blocks
    }
    
    static func randomData(ofLength length: Int) -> Data? {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status == errSecSuccess {
            return Data(bytes: &bytes, count: bytes.count)
        }
        LoggerProxy.debug("Status \(status)")

        return nil
    }
}
