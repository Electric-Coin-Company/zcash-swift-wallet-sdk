//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation
/**
 convenience representation of all transaction types
 */
public protocol TransactionEntity {
    /**
     Internal transaction id
     */
    var id: Int? { get set }
    /**
     Blockchain transaction id
     */
    var transactionId: Data { get set }
    /**
     String representing the date  of creation
     
     format is yyyy-MM-dd'T'HH:MM:ss.SSSSSSSSSZ
     - Example:  2019-12-04T17:49:10.636624000Z
     */
    var created: String? { get set }
    var transactionIndex: Int? { get set }
    var expiryHeight: BlockHeight? { get set }
    var minedHeight: BlockHeight? { get set }
    var raw: Data? { get set }
}
/**
 Hashable extension default implementation
 */
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
/**
 Abstract representation of all transaction types
 */
public protocol AbstractTransaction {
    /**
     internal id for this transaction
     */
    var id: Int? { get set }
    /**
     value in zatoshi
     */
    var value: Int { get set }
    /**
     data containing the memo if any
     */
    var memo: Data? { get set }
}

/**
 Capabilites of a signed transaction
 */
public protocol SignedTransactionEntity {
    var raw: Data? { get set }
}

/**
 capabilities of an entity that can be uniquely identified by a raw transaction id
 */
public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}

/**
 Attributes that a Mined transaction must have
 */
public protocol MinedTransactionEntity: AbstractTransaction, RawIdentifiable {
    /**
     height on which this transaction was mined at. Convention is that -1 is retuned when it has not been mined yet
     */
    var minedHeight: Int { get set }
    
    /**
     internal note id that is involved on this transaction
     */
    var noteId: Int { get set }
    /**
     block time in in reference since 1970
     */
    var blockTimeInSeconds: TimeInterval { get set }
    /**
     internal index for this transaction
     */
    var transactionIndex: Int { get set }
}

public protocol ConfirmedTransactionEntity: MinedTransactionEntity, SignedTransactionEntity {
    /**
     recipient address if available
     */
    var toAddress: String? { get set }
    /**
     expiration height for this transaction
     */
    var expiryHeight: BlockHeight? { get set }
    
}

public extension ConfirmedTransactionEntity {
    var isOutbound: Bool {
        self.toAddress != nil
    }
    var isInbound: Bool {
        self.toAddress == nil
    }
    
    var blockTimeInMilliseconds: Double {
        self.blockTimeInSeconds * 1000
    }
    
}
