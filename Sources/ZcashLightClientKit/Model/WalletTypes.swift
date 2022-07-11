//
//  WalletTypes.swift
//  
//
//  Created by Francisco Gindre on 4/6/21.
//

/**
 Groups a Sapling Extended Full Viewing Key an a tranparent address extended public key.
 */

public typealias ExtendedFullViewingKey = String
public typealias ExtendedPublicKey = String

public protocol UnifiedViewingKey {
    var extfvk: ExtendedFullViewingKey { get set }
    var extpub: ExtendedPublicKey { get set }
}

public typealias TransparentAddress = String
public typealias SaplingShieldedAddress = String

public protocol UnifiedAddress {
    var tAddress: TransparentAddress { get }
    var zAddress: SaplingShieldedAddress { get }
}

public struct WalletBalance {
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
