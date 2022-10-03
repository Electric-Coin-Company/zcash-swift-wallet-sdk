//
//  DerivationTool.swift
//  Pods
//
//  Created by Francisco Gindre on 10/8/20.
//

import Foundation

public protocol KeyValidation {
    func isValidExtendedViewingKey(_ extvk: String) throws -> Bool
    
    func isValidTransparentAddress(_ tAddress: String) throws -> Bool
    
    func isValidSaplingAddress(_ zAddress: String) throws -> Bool

    func isValidSaplingExtendedSpendingKey(_ extsk: String) throws -> Bool

    func isValidUnifiedAddress(_ unifiedAddress: String) throws -> Bool
}

public protocol KeyDeriving {

    /// Given the seed bytes tand the account index, return the UnifiedSpendingKey
    /// - Parameter seed: `[Uint8]` seed bytes
    /// - Parameter accountNumber: `Int` with the account number
    /// - Throws `.unableToDerive` if there's a problem deriving this key
    /// - Returns a `UnifiedSpendingKey`
    func deriveUnifiedSpendingKey(seed: [UInt8], accountIndex: Int) throws -> UnifiedSpendingKey

    /// Extracts the `SaplingAddress` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws `KeyDerivationErrors.receiverNotFound` if the receiver is not present
    static func saplingReceiver(from unifiedAddress: UnifiedAddress) throws -> SaplingAddress?

    /// Extracts the `TransparentAddress` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws `KeyDerivationErrors.receiverNotFound` if the receiver is not present
    static func transparentReceiver(from unifiedAddress: UnifiedAddress) throws -> TransparentAddress?

    /// Extracts the `UnifiedAddress.ReceiverTypecodes` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws
    static func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes]
}

public enum KeyDerivationErrors: Error {
    case derivationError(underlyingError: Error)
    case unableToDerive
    case invalidInput
    case invalidUnifiedAddress
    case receiverNotFound
}

public class DerivationTool: KeyDeriving {
    static var rustwelding: ZcashRustBackendWelding.Type = ZcashRustBackend.self
    
    var networkType: NetworkType
    
    public init(networkType: NetworkType) {
        self.networkType = networkType
    }

    public static func saplingReceiver(from unifiedAddress: UnifiedAddress) throws -> SaplingAddress? {
        try rustwelding.getSaplingReceiver(for: unifiedAddress)
    }

    public static func transparentReceiver(from unifiedAddress: UnifiedAddress) throws -> TransparentAddress? {
        try rustwelding.getTransparentReceiver(for: unifiedAddress)
    }

    /// Given a spending key, return the associated viewing key.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` from which to derive the `UnifiedFullViewingKey` from.
    /// - Returns: the viewing key that corresponds to the spending key.
    public func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey {
        try DerivationTool.rustwelding.deriveUnifiedFullViewingKey(from: spendingKey, networkType: self.networkType)
    }

    /// Given a seed and a number of accounts, return the associated spending keys.
    /// - Parameter seed: the seed from which to derive spending keys.
    /// - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    /// supported so the default value of 1 is recommended.
    /// - Returns: the spending keys that correspond to the seed, formatted as Strings.
    public func deriveUnifiedSpendingKey(seed: [UInt8], accountIndex: Int) throws -> UnifiedSpendingKey {
        guard accountIndex >= 0, let accountIndex = Int32(exactly: accountIndex) else {
            throw KeyDerivationErrors.invalidInput
        }
        do {
            return try DerivationTool.rustwelding.deriveUnifiedSpendingKey(
                from: seed,
                accountIndex: accountIndex,
                networkType: self.networkType
            )
        } catch {
            throw KeyDerivationErrors.unableToDerive
        }
    }

    public static func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes] {
        do {
            return try DerivationTool.rustwelding.receiverTypecodesOnUnifiedAddress(address.stringEncoded)
                .map({ UnifiedAddress.ReceiverTypecodes(typecode: $0) })
        } catch {
            throw KeyDerivationErrors.invalidUnifiedAddress
        }
    }
}

extension DerivationTool: KeyValidation {
    public func isValidUnifiedAddress(_ unifiedAddress: String) throws -> Bool {
        do {
            return try DerivationTool.rustwelding.isValidUnifiedAddress(unifiedAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func isValidExtendedViewingKey(_ extvk: String) throws -> Bool {
        do {
            return try DerivationTool.rustwelding.isValidSaplingExtendedFullViewingKey(extvk, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func isValidTransparentAddress(_ tAddress: String) throws -> Bool {
        do {
            return try DerivationTool.rustwelding.isValidTransparentAddress(tAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func isValidSaplingAddress(_ zAddress: String) throws -> Bool {
        do {
            return try DerivationTool.rustwelding.isValidSaplingAddress(zAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func isValidSaplingExtendedSpendingKey(_ extsk: String) throws -> Bool {
        do {
            return try DerivationTool.rustwelding.isValidSaplingExtendedSpendingKey(extsk, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}


extension TransparentAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}

extension SaplingAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
 }

extension UnifiedAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this..
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}

extension UnifiedFullViewingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String, account: UInt32) {
        self.encoding = validatedEncoding
        self.account = account
    }
}


extension SaplingExtendedFullViewingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}


extension SaplingExtendedSpendingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}

public extension UnifiedSpendingKey {
    func map<T>(_ transform: (UnifiedSpendingKey) throws -> T) rethrows -> T {
        try transform(self)
    }

    func deriveFullViewingKey() throws -> UnifiedFullViewingKey {
        try DerivationTool(networkType: self.network).deriveUnifiedFullViewingKey(from: self)
    }
}

public extension UnifiedAddress {
    /// Extracts the sapling receiver from this UA if available
    /// - Returns: an `Optional<SaplingAddress>`
    func saplingReceiver() -> SaplingAddress? {
        try? DerivationTool.saplingReceiver(from: self)
    }

    /// Extracts the transparent receiver from this UA if available
    /// - Returns: an `Optional<TransparentAddress>`
    func transparentReceiver() -> TransparentAddress? {
        try? DerivationTool.transparentReceiver(from: self)
    }
}
