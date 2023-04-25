//
//  DerivationTool.swift
//  Pods
//
//  Created by Francisco Gindre on 10/8/20.
//

import Combine
import Foundation

public protocol KeyValidation {
    func isValidUnifiedFullViewingKey(_ ufvk: String) -> Bool
    func isValidTransparentAddress(_ tAddress: String) -> Bool
    func isValidSaplingAddress(_ zAddress: String) -> Bool
    func isValidSaplingExtendedSpendingKey(_ extsk: String) -> Bool
    func isValidUnifiedAddress(_ unifiedAddress: String) -> Bool
}

public protocol KeyDeriving {
    /// Given the seed bytes tand the account index, return the UnifiedSpendingKey
    /// - Parameter seed: `[Uint8]` seed bytes
    /// - Parameter accountNumber: `Int` with the account number
    /// - Throws:
    ///     - `derivationToolSpendingKeyInvalidAccount` if the `accountIndex` is invalid.
    ///     - some `ZcashError.rust*` error if the derivation fails.
    /// - Returns a `UnifiedSpendingKey`
    func deriveUnifiedSpendingKey(seed: [UInt8], accountIndex: Int) throws -> UnifiedSpendingKey

    /// Given a spending key, return the associated viewing key.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` from which to derive the `UnifiedFullViewingKey` from.
    /// - Throws: some `ZcashError.rust*` error if the derivation fails.
    /// - Returns: the viewing key that corresponds to the spending key.
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey

    /// Extracts the `SaplingAddress` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws: some `ZcashError.rust*` error if the derivation fails.
    func saplingReceiver(from unifiedAddress: UnifiedAddress) throws -> SaplingAddress

    /// Extracts the `TransparentAddress` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws: some `ZcashError.rust*` error if the derivation fails.
    func transparentReceiver(from unifiedAddress: UnifiedAddress) throws -> TransparentAddress

    /// Extracts the `UnifiedAddress.ReceiverTypecodes` from the given `UnifiedAddress`
    /// - Throws: some `ZcashError.rust*` error if the derivation fails.
    /// - Parameter address: the `UnifiedAddress`
    func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes]

    static func getAddressMetadata(_ addr: String) -> AddressMetadata?
}

public class DerivationTool: KeyDeriving {
    let backend: ZcashKeyDerivationBackendWelding
    
    public init(networkType: NetworkType) {
        self.backend = ZcashKeyDerivationBackend(networkType: networkType)
    }

    public func saplingReceiver(from unifiedAddress: UnifiedAddress) throws -> SaplingAddress {
        try backend.getSaplingReceiver(for: unifiedAddress)
    }

    public func transparentReceiver(from unifiedAddress: UnifiedAddress) throws -> TransparentAddress {
        try backend.getTransparentReceiver(for: unifiedAddress)
    }

    public static func getAddressMetadata(_ addr: String) -> AddressMetadata? {
        ZcashKeyDerivationBackend.getAddressMetadata(addr)
    }

    /// Given a spending key, return the associated viewing key.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` from which to derive the `UnifiedFullViewingKey` from.
    /// - Returns: the viewing key that corresponds to the spending key.
    public func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey {
        try backend.deriveUnifiedFullViewingKey(from: spendingKey)
    }

    /// Given a seed and a number of accounts, return the associated spending keys.
    /// - Parameter seed: the seed from which to derive spending keys.
    /// - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    /// supported so the default value of 1 is recommended.
    /// - Returns: the spending keys that correspond to the seed, formatted as Strings.
    public func deriveUnifiedSpendingKey(seed: [UInt8], accountIndex: Int) throws -> UnifiedSpendingKey {
        guard accountIndex >= 0, let accountIndex = Int32(exactly: accountIndex) else { throw ZcashError.derivationToolSpendingKeyInvalidAccount }
        return try backend.deriveUnifiedSpendingKey(from: seed, accountIndex: accountIndex)
    }

    public func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes] {
        return try backend.receiverTypecodesOnUnifiedAddress(address.stringEncoded)
            .map { UnifiedAddress.ReceiverTypecodes(typecode: $0) }
    }
}

public struct AddressMetadata {
    let networkType: NetworkType
    let addressType: AddressType

    public init(network: NetworkType, addrType: AddressType) {
        self.networkType = network
        self.addressType = addrType
    }
}

extension DerivationTool: KeyValidation {
    public func isValidUnifiedFullViewingKey(_ ufvk: String) -> Bool {
        backend.isValidUnifiedFullViewingKey(ufvk)
    }

    public func isValidUnifiedAddress(_ unifiedAddress: String) -> Bool {
        backend.isValidUnifiedAddress(unifiedAddress)
    }
    
    public func isValidTransparentAddress(_ tAddress: String) -> Bool {
        backend.isValidTransparentAddress(tAddress)
    }
    
    public func isValidSaplingAddress(_ zAddress: String) -> Bool {
        backend.isValidSaplingAddress(zAddress)
    }

    public func isValidSaplingExtendedSpendingKey(_ extsk: String) -> Bool {
        backend.isValidSaplingExtendedSpendingKey(extsk)
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
    init(validatedEncoding: String, networkType: NetworkType) {
        self.encoding = validatedEncoding
        self.networkType = networkType
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
}

public extension UnifiedAddress {
    /// Extracts the sapling receiver from this UA if available
    /// - Returns: an `Optional<SaplingAddress>`
    func saplingReceiver() throws -> SaplingAddress {
        try DerivationTool(networkType: networkType).saplingReceiver(from: self)
    }

    /// Extracts the transparent receiver from this UA if available
    /// - Returns: an `Optional<TransparentAddress>`
    func transparentReceiver() throws -> TransparentAddress {
        try DerivationTool(networkType: networkType).transparentReceiver(from: self)
    }
}
