//
//  AccountEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol AccountEntity {
    var account: Int { get set }
    var extfvk: String { get set }
    var address: String { get set }
    var transparentAddress: String { get set }
}


struct Account: AccountEntity, Encodable, Decodable {
    
    enum CodingKeys: String, CodingKey {
        case account
        case extfvk
        case address
        case transparentAddress = "transparent_address"
    }
    
    var account: Int
    
    var extfvk: String
    
    var address: String
    
    var transparentAddress: String
    
}

extension Account: UnifiedAddress {
    var tAddress: TransparentAddress {
        get {
            transparentAddress
        }
        set {
            transparentAddress = newValue
        }
    }
    
    var zAddress: SaplingShieldedAddress {
        get {
            address
        }
        set {
            address = transparentAddress
        }
    }
}

extension Account: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(account)
        hasher.combine(extfvk)
        hasher.combine(address)
        hasher.combine(transparentAddress)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard   lhs.account == rhs.account,
                lhs.extfvk == rhs.extfvk,
                lhs.address == rhs.address,
                lhs.transparentAddress == rhs.transparentAddress else { return false }
        
        return true
    }
}

protocol AccountRepository {
    func getAll() throws -> [AccountEntity]
    func findBy(account: Int) throws -> AccountEntity?
    func findBy(address: String) throws -> AccountEntity?
    func update(_ account: AccountEntity) throws
}

import SQLite

class AccountSQDAO: AccountRepository {
    
    struct TableColums {
        static let account = Expression<Int>("account")
        static let extfvk = Expression<String>("extfvk")
        static let address = Expression<String>("address")
        static let transparentAddress = Expression<String>("transparent_address")
    }
    var dbProvider: ConnectionProvider
    let table = Table("accounts")
    
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
    
    func findBy(address: String) throws -> AccountEntity? {
        let query = table.filter(TableColums.address == address).limit(1)
        return try dbProvider.connection().prepare(query).map({ try $0.decode() as Account }).first
    }
    
    func update(_ account: AccountEntity) throws {
        guard let a = account as? Account else {
            throw StorageError.updateFailed
        }
        let updatedRows = try dbProvider.connection().run(table.filter(TableColums.account == a.account).update(a))
        if updatedRows == 0 {
            LoggerProxy.error("attempted to update pending transactions but no rows were updated")
            throw StorageError.updateFailed
        }
    }
}

class CachingAccountDao: AccountRepository {
    
    var dao: AccountRepository
    lazy var cache: [Int : AccountEntity] = {
        var c = [Int : AccountEntity]()
        guard let all = try? dao.getAll() else {
            return c
        }
        for a in all {
            c[a.account] = a
        }
        return c
    }()
    
    init(dao: AccountRepository) {
        self.dao = dao
    }
    
    func getAll() throws -> [AccountEntity] {
        guard cache.isEmpty else {
            return cache.values.sorted(by: {$0.account < $1.account})
        }
        let all = try dao.getAll()
        
        for a in all {
            cache[a.account] = a
        }
        return all
    }
    
    func findBy(account: Int) throws -> AccountEntity? {
        if let a = cache[account] {
            return a
        }
        
        let a = try dao.findBy(account: account)
        cache[account] = a
        return a
    }
    
    func findBy(address: String) throws -> AccountEntity? {
        if !cache.isEmpty,
           let account = cache.values.first(where: { $0.address == address }) {
            return account
        }
        
        guard let account = try dao.findBy(address: address) else {
            return nil
        }
        cache[account.account] = account
        
        return account
    }
    
    func update(_ account: AccountEntity) throws {
        try dao.update(account)
    }
    
}
class AccountRepositoryBuilder {
    
    static func build(dataDbURL: URL, readOnly: Bool = false, caching: Bool = false) -> AccountRepository {
        if caching {
            return CachingAccountDao(dao: AccountSQDAO(dbProvider: SimpleConnectionProvider(path: dataDbURL.path, readonly: readOnly)))
        } else {
            return AccountSQDAO(dbProvider: SimpleConnectionProvider(path: dataDbURL.path,readonly: readOnly))
        }
    }
}
