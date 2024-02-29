//
//  Proposal.swift
//
//
//  Created by Jack Grigg on 20/02/2024.
//

import Foundation

/// A data structure that describes a series of transactions to be created.
public struct Proposal: Equatable {
    let inner: FfiProposal

    /// Returns the total fee to be paid across all proposed transactions, in zatoshis.
    public func totalFeeRequired() -> Zatoshi {
        Zatoshi(Int64(inner.balance.feeRequired))
    }
}

public extension Proposal {
    /// IMPORTANT: Use of this function is for testing purposes only, not recommended to use in production.
    /// The instance of `Proposal` should never be created on client's side.
    static func testOnlyFakeProposal(totalFee: UInt64) -> Self {
        var ffiProposal = FfiProposal()
        var balance = FfiTransactionBalance()
        
        balance.feeRequired = totalFee
        
        return Self(inner: ffiProposal)
    }
}
