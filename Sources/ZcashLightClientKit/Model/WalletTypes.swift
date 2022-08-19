//
//  WalletTypes.swift
//  
//
//  Created by Francisco Gindre on 4/6/21.
//

/**
 A ZIP 316 Unified Full Viewing Key.
 */
public protocol UnifiedFullViewingKey {
    var account: UInt32 { get set }
    var encoding: String { get set }
}

public typealias TransparentAddress = String
public typealias SaplingShieldedAddress = String

public protocol UnifiedAddress {
    var encoding: String { get }
}

public struct WalletBalance: Equatable {
    public var verified: Zatoshi
    public var total: Zatoshi

    public init(verified: Zatoshi, total: Zatoshi) {
        self.verified = verified
        self.total = total
    }
}

public extension WalletBalance {
    static var zero: WalletBalance {
        Self(verified: .zero, total: .zero)
    }
}
