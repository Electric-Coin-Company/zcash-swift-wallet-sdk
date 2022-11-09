//
//  AccountEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol AccountEntity {
    var account: Int { get set }
    var ufvk: String { get set }
}

struct Account: AccountEntity, Encodable, Decodable {
    enum CodingKeys: String, CodingKey {
        case account
        case ufvk
    }
    
    var account: Int
    var ufvk: String
}

extension Account: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(account)
        hasher.combine(ufvk)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard
            lhs.account == rhs.account,
            lhs.ufvk == rhs.ufvk
        else { return false }
        
        return true
    }
}

protocol AccountRepository {
    func getAll() throws -> [AccountEntity]
    func findBy(account: Int) throws -> AccountEntity?
    func update(_ account: AccountEntity) throws
}

import SQLite

class AccountSQDAO: AccountRepository {
    enum TableColums {
        static let account = Expression<Int>("account")
        static let extfvk = Expression<String>("ufvk")
    }

    let table = Table("accounts")

    var dbProvider: ConnectionProvider
    
    init (dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func getAll() throws -> [AccountEntity] {
        let allAccounts: [Account] = try dbProvider.connection().prepare(table).map({ row in
            try row.decode()
        })
        
        return allAccounts
    }
    
    func findBy(account: Int) throws -> AccountEntity? {
        let query = table.filter(TableColums.account == account).limit(1)
        return try dbProvider.connection().prepare(query).map({ try $0.decode() as Account }).first
    }
    
    func update(_ account: AccountEntity) throws {
        guard let acc = account as? Account else {
            throw StorageError.updateFailed
        }
        let updatedRows = try dbProvider.connection().run(table.filter(TableColums.account == acc.account).update(acc))
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update pending transactions but no rows were updated")
            throw StorageError.updateFailed
        }
    }
}

class CachingAccountDao: AccountRepository {
    var dao: AccountRepository
    lazy var cache: [Int: AccountEntity] = {
        var accountCache: [Int: AccountEntity] = [:]
        guard let all = try? dao.getAll() else {
            return accountCache
        }

        for acc in all {
            accountCache[acc.account] = acc
        }

        return accountCache
    }()
    
    init(dao: AccountRepository) {
        self.dao = dao
    }
    
    func getAll() throws -> [AccountEntity] {
        guard cache.isEmpty else {
            return cache.values.sorted(by: { $0.account < $1.account })
        }

        let all = try dao.getAll()
        
        for acc in all {
            cache[acc.account] = acc
        }

        return all
    }
    
    func findBy(account: Int) throws -> AccountEntity? {
        if let acc = cache[account] {
            return acc
        }
        
        let acc = try dao.findBy(account: account)
        cache[account] = acc

        return acc
    }
        
    func update(_ account: AccountEntity) throws {
        try dao.update(account)
    }
}

enum AccountRepositoryBuilder {
    static func build(dataDbURL: URL, readOnly: Bool = false, caching: Bool = false) -> AccountRepository {
        if caching {
            return CachingAccountDao(dao: AccountSQDAO(dbProvider: SimpleConnectionProvider(path: dataDbURL.path, readonly: readOnly)))
        } else {
            return AccountSQDAO(dbProvider: SimpleConnectionProvider(path: dataDbURL.path, readonly: readOnly))
        }
    }
}
