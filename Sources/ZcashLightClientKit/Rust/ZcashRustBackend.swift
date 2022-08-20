//
//  ZcashRustBackend.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
// swiftlint:disable type_body_length
import Foundation
import libzcashlc

class ZcashRustBackend: ZcashRustBackendWelding {

    static let minimumConfirmations: UInt32 = 10

    static func lastError() -> RustWeldingError? {
        guard let message = getLastError() else { return nil }

        zcashlc_clear_last_error()

        if message.contains("couldn't load Sapling spend parameters") {
            return RustWeldingError.saplingSpendParametersNotFound
        } else if message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }

        return RustWeldingError.genericError(message: message)
    }
    
    static func getLastError() -> String? {
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
    
    /**
    * Sets up the internal structure of the data database.
    */
    static func initDataDb(dbData: URL, seed: [UInt8]?, networkType: NetworkType) throws -> DbInitResult {
        let dbData = dbData.osStr()
        switch zcashlc_init_data_database(dbData.0, dbData.1, seed, UInt(seed?.count ?? 0), networkType.networkId) {
        case 0: //ok
            return DbInitResult.success
        case 1:
            return DbInitResult.seedRequired
        default:
            if let error = lastError() {
                throw throwDataDbError(error)
            } else {
                throw RustWeldingError.dataDbInitFailed(message: "Database initialization failed: unknown error")
            }
        }
    }
    
    static func isValidSaplingAddress(_ address: String, networkType: NetworkType) throws -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        
        guard zcashlc_is_valid_shielded_address([CChar](address.utf8CString), networkType.networkId) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }
    
    static func isValidTransparentAddress(_ address: String, networkType: NetworkType) throws -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        
        guard zcashlc_is_valid_transparent_address([CChar](address.utf8CString), networkType.networkId ) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }
    
    static func isValidSaplingExtendedFullViewingKey(_ key: String, networkType: NetworkType) throws -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        
        guard zcashlc_is_valid_viewing_key([CChar](key.utf8CString), networkType.networkId) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }

    static func isValidSaplingExtendedSpendingKey(_ key: String, networkType: NetworkType) throws -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        guard zcashlc_is_valid_sapling_extended_spending_key(key, networkType.networkId) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }

    static func isValidUnifiedAddress(_ address: String, networkType: NetworkType) throws -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        guard zcashlc_is_valid_unified_address([CChar](address.utf8CString), networkType.networkId) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }

    static func isValidUnifiedFullViewingKey(_ key: String, networkType: NetworkType) throws -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        guard zcashlc_is_valid_unified_full_viewing_key([CChar](key.utf8CString), networkType.networkId) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }
    
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32, networkType: NetworkType) -> [SaplingExtendedSpendingKey]? {
        let dbData = dbData.osStr()

        guard let ffiEncodingKeysPtr = zcashlc_init_accounts_table(
            dbData.0,
            dbData.1,
            seed,
            UInt(seed.count),
            accounts,
            networkType.networkId
        ) else {
            return nil
        }
        
        let extsks = UnsafeBufferPointer(
            start: ffiEncodingKeysPtr.pointee.ptr,
            count: Int(ffiEncodingKeysPtr.pointee.len)
        ).compactMap({ encodedKey -> SaplingExtendedSpendingKey in
            SaplingExtendedSpendingKey(validatedEncoding: String(cString: encodedKey.encoding))
        })
        zcashlc_free_keys(ffiEncodingKeysPtr)

        return extsks
    }
    
    static func initAccountsTable(
        dbData: URL,
        ufvks: [UnifiedFullViewingKey],
        networkType: NetworkType
    ) throws -> Bool {
        let dbData = dbData.osStr()
        
        var ffiUfvks: [FFIEncodedKey] = []
        for ufvk in ufvks {
            guard !ufvk.encoding.containsCStringNullBytesBeforeStringEnding() else {
                throw RustWeldingError.malformedStringInput
            }
            
            guard try self.isValidUnifiedFullViewingKey(ufvk.encoding, networkType: networkType) else { // TODO Fix
                throw RustWeldingError.malformedStringInput
            }

            let ufvkCStr = [CChar](String(ufvk.encoding).utf8CString)
            
            let ufvkPtr = UnsafeMutablePointer<CChar>.allocate(capacity: ufvkCStr.count)
            ufvkPtr.initialize(from: ufvkCStr, count: ufvkCStr.count)

            ffiUfvks.append(
                FFIEncodedKey(account_id: ufvk.account, encoding: ufvkPtr)
            )
        }
        
        var result = false

        ffiUfvks.withContiguousMutableStorageIfAvailable { pointer in
            let slice = UnsafeMutablePointer<FFIEncodedKeys>.allocate(capacity: 1)

            slice.initialize(
                to: FFIEncodedKeys(
                    ptr: pointer.baseAddress,
                    len: UInt(pointer.count)
                )
            )
            
            result = zcashlc_init_accounts_table_with_keys(dbData.0, dbData.1, slice, networkType.networkId)
            slice.deinitialize(count: 1)
        }
        
        defer {
            for ufvk in ffiUfvks {
                ufvk.encoding.deallocate()
            }
        }
        
        return result
    }
    
    // swiftlint:disable function_parameter_count
    static func initBlocksTable(
        dbData: URL,
        height: Int32,
        hash: String,
        time: UInt32,
        saplingTree: String,
        networkType: NetworkType
    ) throws {
        let dbData = dbData.osStr()
        
        guard !hash.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard !saplingTree.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard zcashlc_init_blocks_table(
            dbData.0,
            dbData.1,
            height,
            [CChar](hash.utf8CString),
            time,
            [CChar](saplingTree.utf8CString),
            networkType.networkId
        ) != 0 else {
            if let error = lastError() {
                throw error
            }
            throw RustWeldingError.dataDbInitFailed(message: "Unknown Error")
        }
    }
    
    static func getAddress(dbData: URL, account: Int32, networkType: NetworkType) -> String? {
        let dbData = dbData.osStr()
        
        guard let addressCStr = zcashlc_get_address(dbData.0, dbData.1, account, networkType.networkId) else { return nil }
        
        let address = String(validatingUTF8: addressCStr)
        zcashlc_string_free(addressCStr)
        return address
    }
    
    static func getBalance(dbData: URL, account: Int32, networkType: NetworkType) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_balance(dbData.0, dbData.1, account, networkType.networkId)
    }
    
    static func getVerifiedBalance(dbData: URL, account: Int32, networkType: NetworkType) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_verified_balance(dbData.0, dbData.1, account, networkType.networkId, minimumConfirmations)
    }
    
    static func getVerifiedTransparentBalance(dbData: URL, address: String, networkType: NetworkType) throws -> Int64 {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard try isValidTransparentAddress(address, networkType: networkType) else {
            throw RustWeldingError.unableToDeriveKeys
        }
        
        let dbData = dbData.osStr()
        
        return zcashlc_get_verified_transparent_balance(dbData.0, dbData.1, [CChar](address.utf8CString), networkType.networkId, minimumConfirmations)
    }
    
    static func getTransparentBalance(dbData: URL, address: String, networkType: NetworkType) throws -> Int64 {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard try self.isValidTransparentAddress(address, networkType: networkType) else {
            throw RustWeldingError.unableToDeriveKeys
        }
        
        let dbData = dbData.osStr()
        return zcashlc_get_total_transparent_balance(dbData.0, dbData.1, [CChar](address.utf8CString), networkType.networkId)
    }
    
    static func clearUtxos(dbData: URL, address: String, sinceHeight: BlockHeight, networkType: NetworkType) throws -> Int32 {
        let dbData = dbData.osStr()
        
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard try isValidTransparentAddress(address, networkType: networkType) else {
            throw RustWeldingError.unableToDeriveKeys
        }
        
        let result = zcashlc_clear_utxos(dbData.0, dbData.1, [CChar](address.utf8CString), Int32(sinceHeight), networkType.networkId)
        
        guard result > 0 else {
            if let error = lastError() {
                throw error
            }
            return result
        }
        return result
    }
    
    static func putUnspentTransparentOutput(dbData: URL, txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight, networkType: NetworkType) throws -> Bool {
        let dbData = dbData.osStr()
        
        guard zcashlc_put_utxo(
            dbData.0,
            dbData.1,
            txid,
            UInt(txid.count),
            Int32(index),
            script,
            UInt(script.count),
            value,
            Int32(height),
            networkType.networkId
        ) else {
            if let error = lastError() {
                throw error
            }
            return false
        }

        return true
    }
    
    static func downloadedUtxoBalance(dbData: URL, address: String, networkType: NetworkType) throws -> WalletBalance {
        let verified = try getVerifiedTransparentBalance(dbData: dbData, address: address, networkType: networkType)
        let total = try getTransparentBalance(dbData: dbData, address: address, networkType: networkType)
        
        return WalletBalance(verified: Zatoshi(verified), total: Zatoshi(total))
    }
    
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64, networkType: NetworkType) -> String? {
        let dbData = dbData.osStr()
        
        guard let memoCStr = zcashlc_get_received_memo_as_utf8(dbData.0, dbData.1, idNote, networkType.networkId) else { return  nil }
        
        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }
    
    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64, networkType: NetworkType) -> String? {
        let dbData = dbData.osStr()
        
        guard let memoCStr = zcashlc_get_sent_memo_as_utf8(dbData.0, dbData.1, idNote, networkType.networkId) else { return nil }
        
        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }
    
    static func validateCombinedChain(dbCache: URL, dbData: URL, networkType: NetworkType) -> Int32 {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_validate_combined_chain(dbCache.0, dbCache.1, dbData.0, dbData.1, networkType.networkId)
    }
    
    static func getNearestRewindHeight(dbData: URL, height: Int32, networkType: NetworkType) -> Int32 {
        let dbData = dbData.osStr()
        return zcashlc_get_nearest_rewind_height(dbData.0, dbData.1, height, networkType.networkId)
    }
    
    static func rewindToHeight(dbData: URL, height: Int32, networkType: NetworkType) -> Bool {
        let dbData = dbData.osStr()
        return zcashlc_rewind_to_height(dbData.0, dbData.1, height, networkType.networkId)
    }
    
    static func scanBlocks(dbCache: URL, dbData: URL, limit: UInt32 = 0, networkType: NetworkType) -> Bool {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_scan_blocks(dbCache.0, dbCache.1, dbData.0, dbData.1, limit, networkType.networkId) != 0
    }

    static func decryptAndStoreTransaction(dbData: URL, txBytes: [UInt8], minedHeight: Int32, networkType: NetworkType) -> Bool {
        let dbData = dbData.osStr()
        return zcashlc_decrypt_and_store_transaction(
            dbData.0,
            dbData.1,
            txBytes,
            UInt(txBytes.count),
            UInt32(minedHeight),
            networkType.networkId
        ) != 0
    }

    // swiftlint:disable function_parameter_count
    static func createToAddress(
        dbData: URL,
        account: Int32,
        extsk: String,
        to address: String,
        value: Int64,
        memo: String?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 {
        let dbData = dbData.osStr()
        let memoBytes = memo ?? ""
        
        return zcashlc_create_to_address(
            dbData.0,
            dbData.1,
            account,
            [CChar](extsk.utf8CString),
            [CChar](address.utf8CString),
            value,
            [CChar](memoBytes.utf8CString),
            spendParamsPath,
            UInt(spendParamsPath.lengthOfBytes(using: .utf8)),
            outputParamsPath,
            UInt(outputParamsPath.lengthOfBytes(using: .utf8)),
            networkType.networkId,
            minimumConfirmations
        )
    }
    
    static func shieldFunds(
        dbCache: URL,
        dbData: URL,
        account: Int32,
        xprv: String,
        memo: String?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 {
        let dbData = dbData.osStr()
        let memoBytes = memo ?? ""
        
        return zcashlc_shield_funds(
            dbData.0,
            dbData.1,
            account,
            [CChar](xprv.utf8CString),
            [CChar](memoBytes.utf8CString),
            spendParamsPath,
            UInt(spendParamsPath.lengthOfBytes(using: .utf8)),
            outputParamsPath,
            UInt(outputParamsPath.lengthOfBytes(using: .utf8)),
            networkType.networkId
        )
    }
    
    static func deriveSaplingExtendedFullViewingKey(_ spendingKey: SaplingExtendedSpendingKey, networkType: NetworkType) throws -> SaplingExtendedFullViewingKey? {
        guard !spendingKey.stringEncoded.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard
            let extfvk = zcashlc_derive_extended_full_viewing_key(
                [CChar](spendingKey.stringEncoded.utf8CString),
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }

        defer { zcashlc_string_free(extfvk) }

        guard let derived = String(validatingUTF8: extfvk) else {
            return nil
        }

        return SaplingExtendedFullViewingKey(validatedEncoding: derived)
    }
    
    static func deriveSaplingExtendedFullViewingKeys(seed: [UInt8], accounts: Int32, networkType: NetworkType) throws -> [SaplingExtendedFullViewingKey]? {

        guard
            let ffiEncodedKeysPtr = zcashlc_derive_extended_full_viewing_keys(
                seed,
                UInt(seed.count),
                accounts,
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }

        defer {
            zcashlc_free_keys(ffiEncodedKeysPtr)
        }
        
        let extfvks = UnsafeBufferPointer(
            start: ffiEncodedKeysPtr.pointee.ptr,
            count: Int(ffiEncodedKeysPtr.pointee.len)
        ).compactMap { encodedKey -> SaplingExtendedFullViewingKey in
            SaplingExtendedFullViewingKey(validatedEncoding: String(cString: encodedKey.encoding))
        }

        return extfvks
    }
    
    static func deriveSaplingExtendedSpendingKeys(seed: [UInt8], accounts: Int32, networkType: NetworkType) throws -> [SaplingExtendedSpendingKey]? {
        guard
            let ffiEncodedKeysPtr = zcashlc_derive_extended_spending_keys(
                seed,
                UInt(seed.count),
                accounts,
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }

        defer { zcashlc_free_keys(ffiEncodedKeysPtr) }

        let extsks = UnsafeBufferPointer(start: ffiEncodedKeysPtr.pointee.ptr, count: Int(ffiEncodedKeysPtr.pointee.len)).compactMap {
            SaplingExtendedSpendingKey(validatedEncoding: String(cString: $0.encoding))
        }


        return extsks
    }

    static func deriveUnifiedFullViewingKeyFromSeed(
        _ seed: [UInt8],
        numberOfAccounts: Int32,
        networkType: NetworkType
    ) throws -> [UnifiedFullViewingKey] {
        guard
            let ffiEncodedKeysPtr = zcashlc_derive_unified_full_viewing_keys_from_seed(
                seed,
                UInt(seed.count),
                Int32(numberOfAccounts),
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            throw RustWeldingError.unableToDeriveKeys
        }

        defer { zcashlc_free_keys(ffiEncodedKeysPtr) }

        let ufvksSize = ffiEncodedKeysPtr.pointee.len

        guard let ufvksArrayPointer = ffiEncodedKeysPtr.pointee.ptr, ufvksSize > 0 else {
            throw RustWeldingError.unableToDeriveKeys
        }

        var ufvks: [UnifiedFullViewingKey] = []
        
        for item in 0 ..< Int(ufvksSize) {
            let itemPointer = ufvksArrayPointer.advanced(by: item)
            
            guard let encoding = String(validatingUTF8: itemPointer.pointee.encoding) else {
                throw RustWeldingError.unableToDeriveKeys
            }
            
            ufvks.append(UnifiedFullViewingKey(validatedEncoding: encoding, account: UInt32(item)))
        }

        
        return ufvks
    }
    
    static func deriveUnifiedAddressFromSeed(
        seed: [UInt8],
        accountIndex: Int32,
        networkType: NetworkType
    ) throws -> String? {
        guard
            let uaddrCStr = zcashlc_derive_unified_address_from_seed(
                seed,
                UInt(seed.count),
                accountIndex,
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        let uAddr = String(validatingUTF8: uaddrCStr)
        
        zcashlc_string_free(uaddrCStr)
        
        return uAddr
    }
    
    static func deriveUnifiedAddressFromViewingKey(
        _ ufvk: String,
        networkType: NetworkType
    ) throws -> String? {
        guard !ufvk.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        guard
            let zaddrCStr = zcashlc_derive_unified_address_from_viewing_key(
                [CChar](ufvk.utf8CString),
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        let uAddr = String(validatingUTF8: zaddrCStr)
        
        zcashlc_string_free(zaddrCStr)
        
        return uAddr
    }
    
    static func deriveTransparentAddressFromSeed(
        seed: [UInt8],
        account: Int,
        index: Int,
        networkType: NetworkType
    ) throws -> String? {
        guard
            let tAddrCStr = zcashlc_derive_transparent_address_from_seed(
                seed,
                UInt(seed.count),
                Int32(account),
                Int32(index),
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        
        let tAddr = String(validatingUTF8: tAddrCStr)
        
        return tAddr
    }
    
    static func deriveTransparentAccountPrivateKeyFromSeed(
        seed: [UInt8],
        account: Int,
        networkType: NetworkType
    ) throws -> String? {
        guard
            let skCStr = zcashlc_derive_transparent_account_private_key_from_seed(
                seed,
                UInt(seed.count),
                Int32(account),
                networkType.networkId
            )
        else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        let secretKey = String(validatingUTF8: skCStr)
        
        return secretKey
    }
    
    static func derivedTransparentAddressFromPublicKey(
        _ pubkey: String,
        networkType: NetworkType
    ) throws -> String {
        guard !pubkey.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard
            let tAddrCStr = zcashlc_derive_transparent_address_from_public_key(
                [CChar](pubkey.utf8CString),
                networkType.networkId
            ),
            let tAddr = String(validatingUTF8: tAddrCStr)
        else {
            if let error = lastError() {
                throw error
            }
            throw RustWeldingError.unableToDeriveKeys
        }

        return tAddr
    }
    
    static func deriveTransparentAddressFromAccountPrivateKey(
        _ tsk: String,
        index: Int,
        networkType: NetworkType
    ) throws -> String? {
        guard !tsk.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard let tAddrCStr = zcashlc_derive_transparent_address_from_account_private_key(
            [CChar](tsk.utf8CString),
            Int32(index),
            networkType.networkId
        ) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }

        let tAddr = String(validatingUTF8: tAddrCStr)
        
        return tAddr
    }
    
    static func consensusBranchIdFor(height: Int32, networkType: NetworkType) throws -> Int32 {
        let branchId = zcashlc_branch_id_for_height(height, networkType.networkId)
        
        guard branchId != -1 else {
            throw RustWeldingError.noConsensusBranchId(height: height)
        }
        
        return branchId
    }
}

private struct UFVK {
    var account: UInt32
    var encoding: String
}

private extension ZcashRustBackend {
    static func throwDataDbError(_ error: RustWeldingError) -> Error {
        if case RustWeldingError.genericError(let message) = error, message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }

        return RustWeldingError.dataDbInitFailed(message: error.localizedDescription)
    }
}

private extension URL {
    func osStr() -> (String, UInt) {
        let path = self.absoluteString
        return (path, UInt(path.lengthOfBytes(using: .utf8)))
    }
}

extension String {
    /**
    Checks whether this string contains null bytes before it's real ending
    */
    func containsCStringNullBytesBeforeStringEnding() -> Bool {
        self.utf8CString.firstIndex(of: 0) != (self.utf8CString.count - 1)
    }
}


fileprivate extension UnifiedFullViewingKey {
    init(ufvk: UFVK) {
        self.account = ufvk.account
        self.encoding = ufvk.encoding
    }
}
