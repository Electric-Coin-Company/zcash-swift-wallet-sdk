//
//  ZcashKeyDerivationBackend.swift
//  
//
//  Created by Francisco Gindre on 4/7/23.
//

import Foundation

protocol ZcashKeyDeriving {
    /// The network type this `ZcashKeyDeriving` implementation is for
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
    /// - Parameter networkType: network type of this key
    /// - Throws `.unableToDerive` when there's an error
    func deriveUnifiedSpendingKey(from seed: [UInt8], accountIndex: Int32) throws -> UnifiedSpendingKey

    /// Derives a `UnifiedFullViewingKey` from a `UnifiedSpendingKey`
    /// - Parameter spendingKey: the `UnifiedSpendingKey` to derive from
    /// - Throws: `RustWeldingError.unableToDeriveKeys` if the SDK couldn't derive the UFVK.
    /// - Returns: the derived `UnifiedFullViewingKey`
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey

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

import libzcashlc

struct ZcashKeyDerivationBackend: ZcashKeyDeriving {
    let networkType: NetworkType
    init(networkType: NetworkType) {
        self.networkType = networkType
    }

    // MARK: Address metadata and validation
    static func getAddressMetadata(_ address: String) -> AddressMetadata? {
        var networkId: UInt32 = 0
        var addrId: UInt32 = 0
        guard zcashlc_get_address_metadata(
            [CChar](address.utf8CString),
            &networkId,
            &addrId
        ) else {
            return nil
        }

        guard
            let network = NetworkType.forNetworkId(networkId),
            let addrType = AddressType.forId(addrId)
        else {
            return nil
        }

        return AddressMetadata(network: network, addrType: addrType)
    }

    func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32] {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.invalidInput(message: "`address` contains null bytes.")
        }

        var len = UInt(0)

        guard let typecodesPointer = zcashlc_get_typecodes_for_unified_address_receivers(
            [CChar](address.utf8CString),
            &len
        ), len > 0
        else {
            throw RustWeldingError.malformedStringInput
        }

        var typecodes: [UInt32] = []

        for typecodeIndex in 0 ..< Int(len) {
            let pointer = typecodesPointer.advanced(by: typecodeIndex)

            typecodes.append(pointer.pointee)
        }

        defer {
            zcashlc_free_typecodes(typecodesPointer, len)
        }

        return typecodes
    }

    func isValidSaplingAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_shielded_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidSaplingExtendedFullViewingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    func isValidSaplingExtendedSpendingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_sapling_extended_spending_key([CChar](key.utf8CString), networkType.networkId)
    }

    func isValidTransparentAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_transparent_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidUnifiedAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidUnifiedFullViewingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_full_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    // MARK: Address Derivation

    func deriveUnifiedSpendingKey(
        from seed: [UInt8],
        accountIndex: Int32
    ) throws -> UnifiedSpendingKey {
        rustBackendGlobalLock.lock()
        defer { rustBackendGlobalLock.unlock() }

        let binaryKeyPtr = seed.withUnsafeBufferPointer { seedBufferPtr in
            return zcashlc_derive_spending_key(
                seedBufferPtr.baseAddress,
                UInt(seed.count),
                accountIndex,
                networkType.networkId
            )
        }

        defer { zcashlc_free_binary_key(binaryKeyPtr) }

        guard let binaryKey = binaryKeyPtr?.pointee else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        return binaryKey.unsafeToUnifiedSpendingKey(network: networkType)
    }
    
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey {
        rustBackendGlobalLock.lock()
        defer { rustBackendGlobalLock.unlock() }

        let extfvk = try spendingKey.bytes.withUnsafeBufferPointer { uskBufferPtr -> UnsafeMutablePointer<CChar> in
            guard let extfvk = zcashlc_spending_key_to_full_viewing_key(
                uskBufferPtr.baseAddress,
                UInt(spendingKey.bytes.count),
                networkType.networkId
            ) else {
                throw lastError() ?? .genericError(message: "No error message available")
            }

            return extfvk
        }

        defer { zcashlc_string_free(extfvk) }

        guard let derived = String(validatingUTF8: extfvk) else {
            throw RustWeldingError.unableToDeriveKeys
        }

        return UnifiedFullViewingKey(validatedEncoding: derived, account: spendingKey.account)
    }

    func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress {
        guard let saplingCStr = zcashlc_get_sapling_receiver_for_unified_address(
            [CChar](uAddr.encoding.utf8CString)
        ) else {
            throw KeyDerivationErrors.invalidUnifiedAddress
        }

        defer { zcashlc_string_free(saplingCStr) }

        guard let saplingReceiverStr = String(validatingUTF8: saplingCStr) else {
            throw KeyDerivationErrors.receiverNotFound
        }

        return SaplingAddress(validatedEncoding: saplingReceiverStr)
    }

    func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress {
        guard let transparentCStr = zcashlc_get_transparent_receiver_for_unified_address(
            [CChar](uAddr.encoding.utf8CString)
        ) else {
            throw KeyDerivationErrors.invalidUnifiedAddress
        }

        defer { zcashlc_string_free(transparentCStr) }

        guard let transparentReceiverStr = String(validatingUTF8: transparentCStr) else {
            throw KeyDerivationErrors.receiverNotFound
        }

        return TransparentAddress(validatedEncoding: transparentReceiverStr)
    }

    // MARK: Error Handling

    private func lastError() -> RustWeldingError? {
        defer { zcashlc_clear_last_error() }

        guard let message = getLastError() else {
            return nil
        }

        if message.contains("couldn't load Sapling spend parameters") {
            return RustWeldingError.saplingSpendParametersNotFound
        } else if message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }

        return RustWeldingError.genericError(message: message)
    }

    private func getLastError() -> String? {
        let errorLen = zcashlc_last_error_length()
        if errorLen > 0 {
            let error = UnsafeMutablePointer<Int8>.allocate(capacity: Int(errorLen))
            zcashlc_error_message_utf8(error, errorLen)
            zcashlc_clear_last_error()
            return String(validatingUTF8: error)
        } else {
            return nil
        }
    }
}
