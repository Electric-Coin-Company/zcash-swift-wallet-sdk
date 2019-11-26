//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

public protocol AccountEntity: Hashable {
    var account: Int { get set }
    var extfvk: String { get set }
    var address: String { get set }
}

public extension AccountEntity {
    func hash(into hasher: inout Hasher) {
        hasher.combine(account)
        hasher.combine(extfvk)
        hasher.combine(address)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard   lhs.account == rhs.account,
                lhs.extfvk == rhs.extfvk,
                lhs.address == rhs.address else { return false }
        
        return true
    }
}
