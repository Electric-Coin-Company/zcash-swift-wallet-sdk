//
//  Proposal.swift
//
//
//  Created by Jack Grigg on 20/02/2024.
//

import Foundation

/// A data structure that describes a series of transactions to be created.
public struct Proposal {
    let inner: FfiProposal

    /// Returns the total fee to be paid across all proposed transactions, in zatoshis.
    public func totalFeeRequired() -> Zatoshi {
        return Zatoshi(Int64(inner.balance.feeRequired))
    }
}
