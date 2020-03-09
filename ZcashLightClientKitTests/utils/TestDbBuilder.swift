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
        self.readWriteDb = FileManager.default.temporaryDirectory.appendingPathComponent(self.originalDb.lastPathComponent.appending("_\(Date().timeIntervalSince1970)")) // avoid files clashing because crashing tests failed to remove previous ones by incrementally changing the filename
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

class TestDbBuilder {
    
    enum TestBuilderError: Error {
        case generalError
    }
    
    static func inMemoryCompactBlockStorage() throws -> CompactBlockStorage {
        let compactBlockDao = CompactBlockStorage(connectionProvider: try InMemoryDbProvider())
        try compactBlockDao.createTable()
        return compactBlockDao
    }
    
    static func diskCompactBlockStorage(at url: URL) throws -> CompactBlockStorage {
        let compactBlockDao = CompactBlockStorage(connectionProvider: SimpleConnectionProvider(path: url.absoluteString))
        try compactBlockDao.createTable()
        return compactBlockDao
    }
    
    static func pendingTransactionsDbURL() throws -> URL {
        try __documentsDirectory().appendingPathComponent("pending.db")
    }
    static func prePopulatedCacheDbURL() -> URL? {
        Bundle(for: TestDbBuilder.self).url(forResource: "cache", withExtension: "db")
    }
    
    static func prePopulatedDataDbURL() -> URL? {
        Bundle(for: TestDbBuilder.self).url(forResource: "test_data", withExtension: "db")
    }
    
    static func prepopulatedDataDbProvider() -> ConnectionProvider? {
        let bundle = Bundle(for: TestDbBuilder.self)
        guard let url = bundle.url(forResource: "ZcashSdk_Data", withExtension: "db") else { return nil }
        let provider = SimpleConnectionProvider(path: url.absoluteString, readonly: true)
        return provider
    }
    
    static func transactionRepository() -> TransactionRepository? {
        guard let provider = prepopulatedDataDbProvider() else { return nil }
        
        return TransactionSQLDAO(dbProvider: provider)
    }
    
    static func sentNotesRepository() -> SentNotesRepository? {
        guard let provider = prepopulatedDataDbProvider() else { return nil }
        return SentNotesSQLDAO(dbProvider: provider)
    }
    
    static func receivedNotesRepository() -> ReceivedNoteRepository? {
        guard let provider = prepopulatedDataDbProvider() else { return nil }
        return ReceivedNotesSQLDAO(dbProvider: provider)
    }
        
    static func seed(db: CompactBlockRepository, with blockRange: CompactBlockRange) throws {
        
        guard let blocks = StubBlockCreator.createBlockRange(blockRange) else {
            throw TestBuilderError.generalError
        }
        
        try db.write(blocks: blocks)
    }
}

struct InMemoryDbProvider: ConnectionProvider {
    var readonly: Bool
    
    var conn: Connection
    init(readonly: Bool = false) throws {
        self.readonly = readonly
        self.conn = try Connection(.inMemory, readonly: readonly)
    }
    
    func connection() throws -> Connection {
        self.conn
    }
}

struct StubBlockCreator {
    static func createRandomDataBlock(with height: BlockHeight) -> ZcashCompactBlock? {
        guard let data = randomData(ofLength: 100) else {
            LoggerProxy.debug("error creating stub block")
            return nil
        }
        return ZcashCompactBlock(height: height, data: data)
    }
    static func createBlockRange(_ range: CompactBlockRange) -> [ZcashCompactBlock]? {
        
        var blocks = [ZcashCompactBlock]()
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
