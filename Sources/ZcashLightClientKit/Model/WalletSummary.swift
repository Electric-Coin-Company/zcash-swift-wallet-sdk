//
//  WalletSummary.swift
//
//
//  Created by Jack Grigg on 06/09/2023.
//

import Foundation

public struct PoolBalance: Equatable {
    public let spendableValue: Zatoshi
    public let changePendingConfirmation: Zatoshi
    public let valuePendingSpendability: Zatoshi

    static let zero = PoolBalance(spendableValue: .zero, changePendingConfirmation: .zero, valuePendingSpendability: .zero)

    public func total() -> Zatoshi {
        self.spendableValue + self.changePendingConfirmation + self.valuePendingSpendability
    }
}

public struct AccountBalance: Equatable {
    public let saplingBalance: PoolBalance
    public let orchardBalance: PoolBalance
    public let unshielded: Zatoshi
    
    static let zero = AccountBalance(saplingBalance: .zero, orchardBalance: .zero, unshielded: .zero)
}

struct ScanProgress: Equatable {
    let numerator: UInt64
    let denominator: UInt64
    
    func progress() throws -> Float {
        guard denominator != 0 else {
            return 1.0
        }

        let value = Float(numerator) / Float(denominator)
        
        // this shouldn't happen but if it does, we need to get notified by clients and work on a fix
        if value > 1.0 {
            throw ZcashError.rustScanProgressOutOfRange("\(value)")
        }

        return value
    }
}

struct WalletSummary: Equatable {
    let accountBalances: [AccountUUID: AccountBalance]
    let chainTipHeight: BlockHeight
    let fullyScannedHeight: BlockHeight
    let recoveryProgress: ScanProgress?
    let scanProgress: ScanProgress?
    let nextSaplingSubtreeIndex: UInt32
    let nextOrchardSubtreeIndex: UInt32
}
