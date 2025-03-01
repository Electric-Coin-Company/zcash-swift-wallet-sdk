//
//  AccountMetadataKey.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 25/02/2025.
//

import Foundation
import libzcashlc

/// A ZIP 325 Account Metadata Key.
public class AccountMetadataKey {
    private let accountMetadataKeyPtr: OpaquePointer
    private let networkType: NetworkType

    /// Derives a ZIP 325 Account Metadata Key from the given seed.
    public init(
        from seed: [UInt8],
        accountIndex: Zip32AccountIndex,
        networkType: NetworkType
    ) async throws {
        let accountMetadataKeyPtr = seed.withUnsafeBufferPointer { seedBufferPtr in
            return zcashlc_derive_account_metadata_key(
                seedBufferPtr.baseAddress,
                UInt(seed.count),
                LCZip32Index(accountIndex.index),
                networkType.networkId
            )
        }

        guard let accountMetadataKeyPtr else {
            throw ZcashError.rustDeriveAccountMetadataKey(lastErrorMessage(fallback: "`deriveAccountMetadataKey` failed with unknown error"))
        }

        self.accountMetadataKeyPtr = accountMetadataKeyPtr
        self.networkType = networkType
    }

    deinit {
        zcashlc_free_account_metadata_key(accountMetadataKeyPtr)
    }

    /// Derives a metadata key for private use from this ZIP 325 Account Metadata Key.
    ///
    /// - Parameter ufvk: the external UFVK for which a metadata key is required, or `null` if the
    ///   metadata key is "inherent" (for the same account as the Account Metadata Key).
    /// - Parameter privateUseSubject: a globally unique non-empty sequence of at most 252 bytes
    ///   that identifies the desired private-use context.
    ///
    /// If `ufvk` is null, this function will return a single 32-byte metadata key.
    ///
    /// If `ufvk` is non-null, this function will return one metadata key for every FVK item
    /// contained within the UFVK, in preference order. As UFVKs may in general change over
    /// time (due to the inclusion of new higher-preference FVK items, or removal of older
    /// deprecated FVK items), private usage of these keys should always follow preference
    /// order:
    /// - For encryption-like private usage, the first key in the array should always be
    ///   used, and all other keys ignored.
    /// - For decryption-like private usage, each key in the array should be tried in turn
    ///   until metadata can be recovered, and then the metadata should be re-encrypted
    ///   under the first key.
    public func derivePrivateUseMetadataKey(
        ufvk: String?,
        privateUseSubject: [UInt8]
    ) async throws -> [Data] {
        var kSource: [CChar]?
        if let ufvk {
            kSource = [CChar](ufvk.utf8CString)
        }

        let keysPtr = privateUseSubject.withUnsafeBufferPointer { privateUseSubjectBufferPtr in
            return zcashlc_derive_private_use_metadata_key(
                accountMetadataKeyPtr,
                kSource,
                privateUseSubjectBufferPtr.baseAddress,
                UInt(privateUseSubject.count),
                networkType.networkId
            )
        }

        guard let keysPtr else {
            throw ZcashError.rustDerivePrivateUseMetadataKey(lastErrorMessage(fallback: "`derivePrivateUseMetadataKey` failed with unknown error"))
        }

        defer { zcashlc_free_txids(keysPtr) }

        var keys: [Data] = []

        for i in (0 ..< Int(keysPtr.pointee.len)) {
            let txId = FfiTxId(tuple: keysPtr.pointee.ptr.advanced(by: i).pointee)
            keys.append(Data(txId.array))
        }

        return keys
    }
}
