//
//  Synchronizer.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/5/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public enum SynchronizerError: Error {
    case initFailed
    case syncFailed
    case generalError(message: String)
}

/**
Primary interface for interacting with the SDK. Defines the contract that specific
implementations like [MockSynchronizer] and [SdkSynchronizer] fulfill. Given the language-level
support for coroutines, we favor their use in the SDK and incorporate that choice into this
contract.
*/

public protocol Synchronizer {
    /**
    Starts this synchronizer within the given scope.
    *
    Implementations should leverage structured concurrency and
    cancel all jobs when this scope completes.
    */
    func start() throws
    
    /**
     Stop this synchronizer. Implementations should ensure that calling this method cancels all
     jobs that were created by this instance.
     */
    func stop() throws
    
    /**
    Value representing the [Status] of this Synchronizer. As the status changes, a new
    value will be emitted by KVO
    */
    var status: Status { get }
    
    /**
     A flow of progress values, typically corresponding to this Synchronizer downloading blocks.
     Typically, any non- zero value below 1.0 indicates that progress indicators can be shown and
     a value of 1.0 signals that progress is complete and any progress indicators can be hidden. KVO Compliant
     */
    var progress: Float { get }
    
    
    /**
    Gets the address for the given account.
    - Parameter accountIndex the optional accountId whose address is of interest. By default, the first account is used.
    */
    func getAddress(accountIndex: Int) -> String
    
    /**
    Sends zatoshi.
    - Parameter spendingKey the key that allows spends to occur.
    - Parameter zatoshi the amount of zatoshi to send.
    - Parameter toAddress the recipient's address.
    - Parameter memo the optional memo to include as part of the transaction.
    - Parameter accountIndex  the optional account id to use. By default, the first account is used.
    */
    func sendToAddress(spendingKey: String, zatoshi: Int64, toAddress: String, memo: String?, from accountIndex: Int, resultBlock: @escaping (_ result: Result<PendingTransactionEntity, Error>) -> Void)
    
    
    /**
       Attempts to cancel a transaction that is about to be sent. Typically, cancellation is only
       an option if the transaction has not yet been submitted to the server.
    
       - Parameter transaction the transaction to cancel.
        - Returns true when the cancellation request was successful. False when it is too late.
       */
    
    func cancelSpend(transaction: PendingTransactionEntity) -> Bool
    
    

}

public enum Status {
    
    /**
    Indicates that [stop] has been called on this Synchronizer and it will no longer be used.
    */
    case stopped
    
    /**
    Indicates that this Synchronizer is disconnected from its lightwalletd server.
    When set, a UI element may want to turn red.
    */
    case disconnected
    
    /**
    Indicates that this Synchronizer is not yet synced and therefore should not broadcast
    transactions because it does not have the latest data. When set, a UI element may want
    to turn yellow.
    */
    case syncing
    
    /**
    Indicates that this Synchronizer is fully up to date and ready for all wallet functions.
    When set, a UI element may want to turn green.
    */
    case synced
}
