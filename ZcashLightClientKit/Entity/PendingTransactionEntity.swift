//
//  PendingTransactionEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/19/19.
//

import Foundation
/**
 Represents a sent transaction that has not been confirmed yet on the blockchain
 */
public protocol PendingTransactionEntity: SignedTransactionEntity, AbstractTransaction, RawIdentifiable {
    /**
     recipient address
     */
    var toAddress: String { get set }
    /**
     index of the account from which the funds were sent
     */
    var accountIndex: Int { get set }
    
    /**
     height which the block was mined at.
     -1 when block has not been mined yet
     */
    var minedHeight: BlockHeight { get set }
    /**
     height for which the represented transaction would be considered expired
     */
    var expiryHeight: BlockHeight { get set }
    /**
    value is 1 if the transaction was cancelled
     */
    var cancelled: Int { get set }
    /**
     how many times this transaction encoding was attempted
     */
    var encodeAttempts: Int { get set }
    /**
     How many attempts to send this transaction have been done
     */
    var submitAttempts: Int { get set }
    /**
     Error message if available.
     */
    var errorMessage: String? { get set }
    /**
     error code, if available
     */
    var errorCode: Int? { get set }
    /**
     create time of the represented transaction
     
     - Note: represented in timeIntervalySince1970
     */
    var createTime: TimeInterval { get set }
    
    /**
     Checks whether this transaction is the same as the given transaction
     */
    func isSameTransactionId<T: RawIdentifiable> (other: T) -> Bool
    
    /**
     returns whether the represented transaction is pending based on the provided block height
     */
    func isPending(currentHeight: Int) -> Bool
    
    /**
     if the represented transaction is being created
     */
    var isCreating: Bool { get }
    
    /**
     returns whether the represented transaction has failed to be encoded
     */
    var isFailedEncoding: Bool { get }
    /**
     returns whether the represented transaction has failed to be submitted
     */
    var isFailedSubmit: Bool { get }
    
    /**
     returns whether the represented transaction presents some kind of error
     */
    var isFailure: Bool { get }
    /**
     returns whether the represented transaction has been cancelled by the user
     */
    var isCancelled: Bool { get }
    /**
     returns whether the represented transaction has been successfully mined
     */
    var isMined: Bool { get }
    /**
     returns whether the represented transaction has been submitted
     */
    var isSubmitted: Bool { get }
    /**
    returns whether the represented transaction has been submitted successfully
    */
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
        isSubmitSuccess && !isConfirmed(currentHeight: currentHeight) && (expiryHeight == -1 || expiryHeight > currentHeight) && raw != nil
    }
        
    var isSubmitSuccess: Bool {
        submitAttempts > 0 && (errorCode == nil || (errorCode ?? 0) >= 0) && errorMessage == nil
    }
    
    func isConfirmed(currentHeight: Int = -1 ) -> Bool {
        guard minedHeight > 0 else {
            return false
        }
        
        guard currentHeight > 0 else {
            return false
        }
        
        return abs(currentHeight - minedHeight) >= ZcashSDK.DEFAULT_STALE_TOLERANCE
    }
}

public extension PendingTransactionEntity {
    /**
     TransactionEntity representation of this PendingTransactionEntity transaction
     */
    var transactionEntity: TransactionEntity {
        Transaction(id: self.id ?? -1, transactionId: self.rawTransactionId ?? Data(), created: Date(timeIntervalSince1970: self.createTime).description, transactionIndex: -1, expiryHeight: self.expiryHeight, minedHeight: self.minedHeight, raw: self.raw)
    }
}

public extension ConfirmedTransactionEntity {
    /**
    TransactionEntity representation of this ConfirmedTransactionEntity transaction
    */
    var transactionEntity: TransactionEntity {
        Transaction(id: self.id ?? -1, transactionId: self.rawTransactionId ?? Data(), created: Date(timeIntervalSince1970: self.blockTimeInSeconds).description, transactionIndex: self.transactionIndex, expiryHeight: self.expiryHeight, minedHeight: self.minedHeight, raw: self.raw)
    }
}
