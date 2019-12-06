//
//  PendingTransactionEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation

public protocol PendingTransactionEntity: SignedTransactionEntity, AbstractTransaction, RawIdentifiable {
    var toAddress: String { get set }
    var accountIndex: Int { get set }
    var minedHeight: BlockHeight { get set }
    var expiryHeight: BlockHeight { get set }
    var cancelled: Int { get set }
    var encodeAttempts: Int { get set }
    var submitAttempts: Int { get set }
    var errorMessage: String? { get set }
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

public extension PendingTransactionEntity {
    func isSameTransaction<T: RawIdentifiable>(other: T) -> Bool {
        guard let selfId = self.rawTransactionId, let otherId = other.rawTransactionId else { return false }
        return selfId == otherId
    }
    
    var isCreating: Bool {
        (raw?.isEmpty ?? true) != false && submitAttempts <= 0 && !isFailedSubmit && !isFailedEncoding
    }
    
    var isFailedEncoding: Bool {
        (raw?.isEmpty ?? true) != false && encodeAttempts > 0
    }
    
    var isFailedSubmit: Bool {
        errorMessage != nil || (errorCode != nil && (errorCode ?? 0) < 0)
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
        submitAttempts > 0 && (errorCode != nil && (errorCode ?? -1) >= 0) && errorMessage == nil
    }
}

public extension PendingTransactionEntity {
    var transactionEntity: TransactionEntity {
        Transaction(id: self.id ?? -1, transactionId: self.rawTransactionId ?? Data(), created: Date(timeIntervalSince1970: self.createTime).description, transactionIndex: -1, expiryHeight: self.expiryHeight, minedHeight: self.minedHeight, raw: self.raw)
    }
}

public extension ConfirmedTransactionEntity {
    var transactionEntity: TransactionEntity {
        Transaction(id: self.id ?? -1, transactionId: self.rawTransactionId ?? Data(), created: Date(timeIntervalSince1970: self.blockTimeInSeconds).description, transactionIndex: self.transactionIndex, expiryHeight: self.expiryHeight, minedHeight: self.minedHeight, raw: self.raw)
    }
}
