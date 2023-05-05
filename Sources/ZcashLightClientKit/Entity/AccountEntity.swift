//
//  AccountEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation
import SQLite

protocol AccountEntity {
    var account: Int { get }
    var ufvk: String { get }
}

struct DbAccount: AccountEntity, Encodable, Decodable {
    enum CodingKeys: String, CodingKey {
        case account
        case ufvk
    }
    
    let account: Int
    let ufvk: String
}

extension DbAccount: Hashable {
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

class AccountSQDAO: AccountRepository {
    enum TableColums {
        static let account = Expression<Int>("account")
        static let extfvk = Expression<String>("ufvk")
    }

    let table = Table("accounts")

    let dbProvider: ConnectionProvider
    let logger: Logger
    
    init(dbProvider: ConnectionProvider, logger: Logger) {
        self.dbProvider = dbProvider
        self.logger = logger
    }

    /// - Throws:
    ///     - `accountDAOGetAllCantDecode` if account data fetched from the db can't be decoded to the `Account` object.
    ///     - `accountDAOGetAll` if sqlite query fetching account data failed.
    func getAll() throws -> [AccountEntity] {
        do {
            return try dbProvider.connection()
                .prepare(table)
                .map { row -> DbAccount in
                    do {
                        return try row.decode()
                    } catch {
                        throw ZcashError.accountDAOGetAllCantDecode(error)
                    }
                }
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.accountDAOGetAll(error)
            }
        }
    }

    /// - Throws:
    ///     - `accountDAOFindByCantDecode` if account data fetched from the db can't be decoded to the `Account` object.
    ///     - `accountDAOFindBy` if sqlite query fetching account data failed.
    func findBy(account: Int) throws -> AccountEntity? {
        let query = table.filter(TableColums.account == account).limit(1)
        do {
            return try dbProvider.connection()
                .prepare(query)
                .map {
                    do {
                        return try $0.decode() as DbAccount
                    } catch {
                        throw ZcashError.accountDAOFindByCantDecode(error)
                    }
                }
                .first
        } catch {
            if let error = error as? ZcashError {
                throw error
            } else {
                throw ZcashError.accountDAOFindBy(error)
            }
        }
    }

    /// - Throws:
    ///     - `accountDAOUpdate` if sqlite query updating account failed.
    ///     - `accountDAOUpdatedZeroRows` if sqlite query updating account pass but it affects 0 rows.
    func update(_ account: AccountEntity) throws {
        guard let acc = account as? DbAccount else {
            throw ZcashError.accountDAOUpdateInvalidAccount
        }

        let updatedRows: Int
        do {
            updatedRows = try dbProvider.connection().run(table.filter(TableColums.account == acc.account).update(acc))
        } catch {
            throw ZcashError.accountDAOUpdate(error)
        }

        if updatedRows == 0 {
            logger.error("attempted to update pending transactions but no rows were updated")
            throw ZcashError.accountDAOUpdatedZeroRows
        }
    }
}

class CachingAccountDao: AccountRepository {
    let dao: AccountRepository
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
    static func build(dataDbURL: URL, readOnly: Bool = false, caching: Bool = false, logger: Logger) -> AccountRepository {
        if caching {
            return CachingAccountDao(
                dao: AccountSQDAO(
                    dbProvider: SimpleConnectionProvider(path: dataDbURL.path, readonly: readOnly),
                    logger: logger
                )
            )
        } else {
            return AccountSQDAO(
                dbProvider: SimpleConnectionProvider(path: dataDbURL.path, readonly: readOnly),
                logger: logger
            )
        }
    }
}
