//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

public protocol TransactionEntity: Identifiable, Hashable {
    var transactionId: Data { get set }
    var created: String? { get set }
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

public protocol Transaction: Identifiable {
    var value: Int { get set }
    var memo: Data? { get set }
}

public protocol SignedTransaction {
    var raw: Data? { get set }
}

public protocol RawIdentifiable {
    var rawTransactionId: Data? { get set }
}
public protocol MinedTransaction: Transaction, RawIdentifiable {
    var minedHeight: Int { get set }
    var noteId: Int { get set }
    var blockTimeInSeconds: TimeInterval { get set }
    var transactionIndex: Int { get set }
}

public protocol PendingTransaction: SignedTransaction, Transaction, RawIdentifiable {
    var toAddress: String { get set }
    var accountIndex: Int { get set }
    var minedHeight: BlockHeight { get set }
    var expiryHeight: BlockHeight { get set }
    var cancelled: Int { get set }
    var encodeAttempts: Int { get set }
    var submitAttempts: Int { get set }
    var errorMesssage: String? { get set }
    var errorCode: Int? { get set }
    var createTime: TimeInterval { get set }
    
    func isSameTransactionId<T: RawIdentifiable> (other: T) -> Bool
    func isPending(currentHeight: Int) -> Bool
    
    var isCreating: Bool { get }
    var isFailedEncoding: Bool { get }
    var isFailedSubmit: Bool { get }
    var isFailure: Bool { get }
    var isCancelled: Bool { get }
    var isMined: Bool { get }
    var isSubmitted: Bool { get }
    var isSubmitSuccess: Bool { get }
}

public extension PendingTransaction {
    func isSameTransaction<T: RawIdentifiable>(other: T) -> Bool {
        guard let selfId  = self.rawTransactionId, let otherId = other.rawTransactionId else { return false }
        return selfId == otherId
    }
    
    var isCreating: Bool {
        (raw?.isEmpty ?? true) != false && submitAttempts <= 0 && !isFailedSubmit && !isFailedEncoding
    }
    
    var isFailedEncoding: Bool {
        (raw?.isEmpty ?? true) != false && encodeAttempts > 0
    }
    
    var isFailedSubmit: Bool {
        errorMesssage != nil || (errorCode != nil && (errorCode ?? 0) < 0)
    }
    
    var isFailure: Bool {
        isFailedEncoding || isFailedSubmit
    }
    
    var isCancelled: Bool {
        cancelled > 0
    }
    
    var isMined: Bool {
        minedHeight > 0
    }
    
    var isSubmitted: Bool {
        submitAttempts > 0
    }
    
    func isPending(currentHeight: Int = -1) -> Bool {
        // not mined and not expired and successfully created
        !isSubmitSuccess && minedHeight == -1 && (expiryHeight == -1 || expiryHeight > currentHeight) && raw != nil
    }
        
    var isSubmitSuccess: Bool {
        submitAttempts > 0 && (errorCode != nil && (errorCode ?? -1) >= 0) && errorMesssage == nil
    }
}

