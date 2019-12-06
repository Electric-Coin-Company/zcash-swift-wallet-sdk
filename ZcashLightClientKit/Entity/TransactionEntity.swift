//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

public protocol TransactionEntity {
    var id: Int? { get set }
    var transactionId: Data { get set }
    var created: String? { get set }
    var transactionIndex: Int { get set }
    var expiryHeight: BlockHeight? { get set }
    var minedHeight: BlockHeight? { get set }
    var raw: Data? { get set }
}

public extension TransactionEntity {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(transactionId)
        hasher.combine(expiryHeight)
        hasher.combine(minedHeight)
        hasher.combine(raw)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard   lhs.id == rhs.id,
                lhs.transactionId == rhs.transactionId,
                lhs.created == rhs.created,
                lhs.expiryHeight == rhs.expiryHeight,
                lhs.minedHeight == rhs.minedHeight,
            ((lhs.raw != nil && rhs.raw != nil) || (lhs.raw == nil && rhs.raw == nil)) else { return false }
        
        if let lhsRaw = lhs.raw, let rhsRaw = rhs.raw {
            return lhsRaw == rhsRaw
        }
        
        return true
    }
}

public protocol AbstractTransaction {
    var id: Int? { get set }
    var value: Int { get set }
    var memo: Data? { get set }
}

public protocol SignedTransactionEntity {
    var raw: Data? { get set }
}

public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}
public protocol MinedTransactionEntity: AbstractTransaction, RawIdentifiable {
    var minedHeight: Int { get set }
    var noteId: Int { get set }
    var blockTimeInSeconds: TimeInterval { get set }
    var transactionIndex: Int { get set }
}

public protocol ConfirmedTransactionEntity: MinedTransactionEntity, SignedTransactionEntity {
    var toAddress: String? { get set }
    var expiryHeight: BlockHeight? { get set }
}
