//
//  ZcashKeyDerivationBackendWelding.swift
//  
//
//  Created by Michal Fousek on 11.04.2023.
//

import Foundation

protocol ZcashKeyDerivationBackendWelding {
    /// The network type this `ZcashKeyDerivationBackendWelding` implementation is for
    var networkType: NetworkType { get }

    /// Returns the network and address type for the given Zcash address string,
    /// if the string represents a valid Zcash address.
    /// - Note: not `NetworkType` bound
    static func getAddressMetadata(_ address: String) -> AddressMetadata?

    /// Obtains the available receiver typecodes for the given String encoded Unified Address
    /// - Parameter address: public key represented as a String
    /// - Returns  the `[UInt32]` that compose the given UA
    /// - Note: not `NetworkType` bound
    /// - Throws:
    ///     - `rustReceiverTypecodesOnUnifiedAddressContainsNullBytes` if `address` contains null bytes before end.
    ///     - `rustRustReceiverTypecodesOnUnifiedAddressMalformed` if getting typecodes for unified address fails.
    func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32]

    /// Validates the if the given string is a valid Sapling Address
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Returns: true when the address is valid. Returns false in any other case
    func isValidSaplingAddress(_ address: String) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Full Viewing Key
    /// - Parameter key: UTF-8 encoded String to validate
    /// - Returns: `true` when the Sapling Extended Full Viewing Key is valid. `false` in any other case
    func isValidSaplingExtendedFullViewingKey(_ key: String) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Spending Key
    /// - Returns: `true` when the Sapling Extended Spending Key is valid, false in any other case.
    /// - parameter key: String encoded Extended Spending Key
    func isValidSaplingExtendedSpendingKey(_ key: String) -> Bool

    /// Validates the if the given string is a valid Transparent Address
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Returns: true when the address is valid and transparent. false in any other case
    func isValidTransparentAddress(_ address: String) -> Bool

    /// validates whether a string encoded address is a valid Unified Address.
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Returns: true when the address is valid and transparent. false in any other case
    func isValidUnifiedAddress(_ address: String) -> Bool

    ///  verifies that the given string-encoded `UnifiedFullViewingKey` is valid.
    /// - Parameter ufvk: UTF-8 encoded String to validate
    /// - Returns: true when the encoded string is a valid UFVK. false in any other case
    func isValidUnifiedFullViewingKey(_ ufvk: String) -> Bool

    /// Derives and returns a unified spending key from the given seed for the given account ID.
    /// Returns the binary encoding of the spending key. The caller should manage the memory of (and store, if necessary) the returned spending key in a secure fashion.
    /// - Parameter seed: a Byte Array with the seed
    /// - Parameter accountIndex:account index that the key can spend from
    /// - Throws: `rustDeriveUnifiedSpendingKey` if rust layer returns error.
    func deriveUnifiedSpendingKey(from seed: [UInt8], accountIndex: Int32) throws -> UnifiedSpendingKey

    /// Derives a `UnifiedFullViewingKey` from a `UnifiedSpendingKey`
    /// - Parameter spendingKey: the `UnifiedSpendingKey` to derive from
    /// - Returns: the derived `UnifiedFullViewingKey`
    /// - Throws:
    ///     - `rustDeriveUnifiedFullViewingKey` if rust layer returns error.
    ///     - `rustDeriveUnifiedFullViewingKeyInvalidDerivedKey` if derived viewing key is invalid.
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey

    /// Returns the Sapling receiver within the given Unified Address, if any.
    /// - Parameter uAddr: a `UnifiedAddress`
    /// - Returns a `SaplingAddress` if any
    /// - Throws:
    ///     - `rustGetSaplingReceiverInvalidAddress` if failed to get sapling receiver for unified address.
    ///     - `rustGetSaplingReceiverInvalidReceiver` if generated sapling receiver is invalid.
    func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress

    /// Returns the transparent receiver within the given Unified Address, if any.
    /// - parameter uAddr: a `UnifiedAddress`
    /// - Returns a `TransparentAddress` if any
    /// - Throws:
    ///     - `rustGetTransparentReceiverInvalidAddress` if failed to get transparent receiver for unified address.
    ///     - `rustGetTransparentReceiverInvalidReceiver` if generated transparent receiver is invalid.
    func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress
}
