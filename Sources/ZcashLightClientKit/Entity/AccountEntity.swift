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
