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

    /// Validates the if the given string is a valid Sapling Extended Full Viewing Key
    /// - Parameter key: UTF-8 encoded String to validate
    /// - Returns: `true` when the Sapling Extended Full Viewing Key is valid. `false` in any other case
    func isValidSaplingExtendedFullViewingKey(_ key: String) -> Bool

    /// Validates the if the given string is a valid Sapling Extended Spending Key
    /// - Returns: `true` when the Sapling Extended Spending Key is valid, false in any other case.
    /// - parameter key: String encoded Extended Spending Key
    func isValidSaplingExtendedSpendingKey(_ key: String) -> Bool

    ///  verifies that the given string-encoded `UnifiedFullViewingKey` is valid.
    /// - Parameter ufvk: UTF-8 encoded String to validate
    /// - Returns: true when the encoded string is a valid UFVK. false in any other case
    func isValidUnifiedFullViewingKey(_ ufvk: String) -> Bool

    /// Derives and returns a unified spending key from the given seed for the given account ID.
    /// Returns the binary encoding of the spending key. The caller should manage the memory of (and store, if necessary) the returned spending key in a secure fashion.
    /// - Parameter seed: a Byte Array with the seed
    /// - Parameter account:account that the key can spend from
    /// - Throws: `rustDeriveUnifiedSpendingKey` if rust layer returns error.
    func deriveUnifiedSpendingKey(from seed: [UInt8], account: Account) throws -> UnifiedSpendingKey

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

    /// Derives and returns a ZIP 32 Arbitrary Key from the given seed at the "wallet level", i.e.
    /// directly from the seed with no ZIP 32 path applied.
    ///
    /// The resulting key will be the same across all networks (Zcash mainnet, Zcash testnet,
    /// OtherCoin mainnet, and so on). You can think of it as a context-specific seed fingerprint
    /// that can be used as (static) key material.
    ///
    /// - Parameter contextString: a globally-unique non-empty sequence of at most 252 bytes that identifies the desired context.
    /// - Parameter seed: `[Uint8]` seed bytes
    /// - Throws:
    ///     - `derivationToolInvalidAccount` if the `account.id` is invalid.
    ///     - some `ZcashError.rust*` error if the derivation fails.
    /// - Returns a `[Uint8]`
    static func deriveArbitraryWalletKey(
        contextString: [UInt8],
        from seed: [UInt8]
    ) throws -> [UInt8]

    /// Derives and returns a ZIP 32 Arbitrary Key from the given seed at the account level.
    ///
    /// - Parameter contextString: a globally-unique non-empty sequence of at most 252 bytes that identifies the desired context.
    /// - Parameter seed: `[Uint8]` seed bytes
    /// - Parameter account: `Account` with the account number
    /// - Throws:
    ///     - `derivationToolInvalidAccount` if the `account.id` is invalid.
    ///     - some `ZcashError.rust*` error if the derivation fails.
    /// - Returns a `[Uint8]`
    func deriveArbitraryAccountKey(
        contextString: [UInt8],
        from seed: [UInt8],
        account: Account
    ) throws -> [UInt8]
}
