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
    /// - Throws `RustWeldingError.invalidInput(message: String)` when the UA is either invalid or malformed
    /// - Note: not `NetworkType` bound
    func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32]

    /// Validates the if the given string is a valid Sapling Address
    /// - Parameter address: UTF-8 encoded String to validate
    /// - Returns: true when the address is valid. Returns false in any other case
    /// - Throws: Error when the provided address belongs to another network
    func isValidSaplingAddress(_ address: String) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Full Viewing Key
    /// - Parameter key: UTF-8 encoded String to validate
    /// - Returns: `true` when the Sapling Extended Full Viewing Key is valid. `false` in any other case
    /// - Throws: Error when there's another problem not related to validity of the string in question
    func isValidSaplingExtendedFullViewingKey(_ key: String) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Spending Key
    /// - Returns: `true` when the Sapling Extended Spending Key is valid, false in any other case.
    /// - Throws: Error when the key is semantically valid  but it belongs to another network
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
    func deriveUnifiedSpendingKey(from seed: [UInt8], accountIndex: Int32) async throws -> UnifiedSpendingKey

    /// Derives a `UnifiedFullViewingKey` from a `UnifiedSpendingKey`
    /// - Parameter spendingKey: the `UnifiedSpendingKey` to derive from
    /// - Throws: `RustWeldingError.unableToDeriveKeys` if the SDK couldn't derive the UFVK.
    /// - Returns: the derived `UnifiedFullViewingKey`
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) async throws -> UnifiedFullViewingKey

    /// Returns the Sapling receiver within the given Unified Address, if any.
    /// - Parameter uAddr: a `UnifiedAddress`
    /// - Returns a `SaplingAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress

    /// Returns the transparent receiver within the given Unified Address, if any.
    /// - parameter uAddr: a `UnifiedAddress`
    /// - Returns a `TransparentAddress` if any
    /// - Throws `receiverNotFound` when the receiver is not found. `invalidUnifiedAddress` if the UA provided is not valid
    func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress
}
