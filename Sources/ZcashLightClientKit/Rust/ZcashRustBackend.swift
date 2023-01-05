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
    static let useZIP317Fees = false
    static func createAccount(dbData: URL, seed: [UInt8], networkType: NetworkType) throws -> UnifiedSpendingKey {
        let dbData = dbData.osStr()

        guard let ffiBinaryKeyPtr = zcashlc_create_account(
            dbData.0,
            dbData.1,
            seed,
            UInt(seed.count),
            networkType.networkId
        ) else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        defer { zcashlc_free_binary_key(ffiBinaryKeyPtr) }

        return ffiBinaryKeyPtr.pointee.unsafeToUnifiedSpendingKey(network: networkType)
    }

    // swiftlint:disable function_parameter_count
    static func createToAddress(
        dbData: URL,
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 {
        let dbData = dbData.osStr()

        return usk.bytes.withUnsafeBufferPointer { uskPtr in
            zcashlc_create_to_address(
                dbData.0,
                dbData.1,
                uskPtr.baseAddress,
                UInt(usk.bytes.count),
                [CChar](address.utf8CString),
                value,
                memo?.bytes,
                spendParamsPath,
                UInt(spendParamsPath.lengthOfBytes(using: .utf8)),
                outputParamsPath,
                UInt(outputParamsPath.lengthOfBytes(using: .utf8)),
                networkType.networkId,
                minimumConfirmations,
                useZIP317Fees
            )
        }
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

    static func deriveUnifiedSpendingKey(
        from seed: [UInt8],
        accountIndex: Int32,
        networkType: NetworkType
    ) throws -> UnifiedSpendingKey {

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

    static func getBalance(dbData: URL, account: Int32, networkType: NetworkType) throws -> Int64 {
        let dbData = dbData.osStr()

        let balance = zcashlc_get_balance(dbData.0, dbData.1, account, networkType.networkId)

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage: "Error getting total balance from account \(account)")
        }

        return balance
    }

    static func getCurrentAddress(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> UnifiedAddress {
        let dbData = dbData.osStr()

        guard let addressCStr = zcashlc_get_current_address(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        ) else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        defer { zcashlc_string_free(addressCStr) }

        guard let address = String(validatingUTF8: addressCStr) else {
            throw RustWeldingError.unableToDeriveKeys
        }

        return UnifiedAddress(validatedEncoding: address)
    }

    static func getNearestRewindHeight(
        dbData: URL,
        height: Int32,
        networkType: NetworkType
    ) -> Int32 {
        let dbData = dbData.osStr()

        return zcashlc_get_nearest_rewind_height(
            dbData.0,
            dbData.1,
            height,
            networkType.networkId
        )
    }

    static func getNextAvailableAddress(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> UnifiedAddress {
        let dbData = dbData.osStr()

        guard let addressCStr = zcashlc_get_next_available_address(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        ) else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        defer { zcashlc_string_free(addressCStr) }

        guard let address = String(validatingUTF8: addressCStr) else {
            throw RustWeldingError.unableToDeriveKeys
        }

        return UnifiedAddress(validatedEncoding: address)
    }

    @available(*, deprecated, message: "This function will be deprecated soon. Use `getReceivedMemo(dbData:idNote:networkType)` instead")
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64, networkType: NetworkType) -> String? {
        let dbData = dbData.osStr()

        guard let memoCStr = zcashlc_get_received_memo_as_utf8(
            dbData.0,
            dbData.1,
            idNote,
            networkType.networkId
        ) else { return  nil }

        defer {
            zcashlc_string_free(memoCStr)
        }

        return String(validatingUTF8: memoCStr)
    }

    static func getReceivedMemo(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> Memo? {
        let dbData = dbData.osStr()

        var contiguousMemoBytes = ContiguousArray<UInt8>(MemoBytes.empty().bytes)
        var success = false

        contiguousMemoBytes.withUnsafeMutableBufferPointer { memoBytePtr in
            success = zcashlc_get_received_memo(dbData.0, dbData.1, idNote, memoBytePtr.baseAddress, networkType.networkId)
        }

        guard success else { return nil }

        return (try? MemoBytes(contiguousBytes: contiguousMemoBytes)).flatMap { try? $0.intoMemo() }
    }

    static func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress? {
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

    @available(*, deprecated, message: "This function will be deprecated soon. Use `getSentMemo(dbData:idNote:networkType)` instead")
    static func getSentMemoAsUTF8(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> String? {
        let dbData = dbData.osStr()

        guard let memoCStr = zcashlc_get_sent_memo_as_utf8(dbData.0, dbData.1, idNote, networkType.networkId) else { return nil }

        defer {
            zcashlc_string_free(memoCStr)
        }

        return String(validatingUTF8: memoCStr)
    }

    static func getSentMemo(
        dbData: URL,
        idNote: Int64,
        networkType: NetworkType
    ) -> Memo? {
        let dbData = dbData.osStr()

        var contiguousMemoBytes = ContiguousArray<UInt8>(MemoBytes.empty().bytes)
        var success = false

        contiguousMemoBytes.withUnsafeMutableBytes{ memoBytePtr in
            success = zcashlc_get_sent_memo(dbData.0, dbData.1, idNote, memoBytePtr.baseAddress, networkType.networkId)
        }

        guard success else { return nil }

        return (try? MemoBytes(contiguousBytes: contiguousMemoBytes)).flatMap { try? $0.intoMemo() }
    }

    static func getTransparentBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64 {
        guard account >= 0 else {
            throw RustWeldingError.invalidInput(message: "Account index must be non-negative")
        }

        let dbData = dbData.osStr()
        let balance = zcashlc_get_total_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account
        )

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage:  "Error getting Total Transparent balance from account \(account)")
        }

        return balance
    }

    static func getVerifiedBalance(dbData: URL, account: Int32, networkType: NetworkType) throws -> Int64 {
        let dbData = dbData.osStr()
        let balance = zcashlc_get_verified_balance(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId,
            minimumConfirmations
        )

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage: "Error getting verified balance from account \(account)")
        }

        return balance
    }

    static func getVerifiedTransparentBalance(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> Int64 {
        guard account >= 0 else {
            throw RustWeldingError.invalidInput(message: "`account` must be non-negative")
        }

        let dbData = dbData.osStr()

        let balance = zcashlc_get_verified_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account,
            minimumConfirmations
        )

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage: "Error getting verified transparent balance from account \(account)")
        }

        return balance
    }
    
    static func lastError() -> RustWeldingError? {
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
        
        guard let network = NetworkType.forNetworkId(networkId),
              let addrType = AddressType.forId(addrId)
        else {
            return nil
        }
                    
        return AddressMetadata(network: network, addrType: addrType)
    }
    
    static func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress? {
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

    static func initDataDb(dbData: URL, seed: [UInt8]?, networkType: NetworkType) throws -> DbInitResult {
        let dbData = dbData.osStr()
        switch zcashlc_init_data_database(dbData.0, dbData.1, seed, UInt(seed?.count ?? 0), networkType.networkId) {
        case 0: //ok
            return DbInitResult.success
        case 1:
            return DbInitResult.seedRequired
        default:
            throw throwDataDbError(lastError() ?? .genericError(message: "No error message found"))
        }
    }
    
    static func isValidSaplingAddress(_ address: String, networkType: NetworkType)  -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        
        return zcashlc_is_valid_shielded_address([CChar](address.utf8CString), networkType.networkId)
    }
    
    static func isValidTransparentAddress(_ address: String, networkType: NetworkType)  -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_transparent_address([CChar](address.utf8CString), networkType.networkId)
    }
    
    static func isValidSaplingExtendedFullViewingKey(_ key: String, networkType: NetworkType) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    static func isValidSaplingExtendedSpendingKey(_ key: String, networkType: NetworkType) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_sapling_extended_spending_key([CChar](key.utf8CString), networkType.networkId)
    }

    static func isValidUnifiedAddress(_ address: String, networkType: NetworkType) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_address([CChar](address.utf8CString), networkType.networkId)
    }

    static func isValidUnifiedFullViewingKey(_ key: String, networkType: NetworkType) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_full_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    static func initAccountsTable(
        dbData: URL,
        ufvks: [UnifiedFullViewingKey],
        networkType: NetworkType
    ) throws {
        let dbData = dbData.osStr()
        
        var ffiUfvks = [FFIEncodedKey]()
        for ufvk in ufvks {
            guard !ufvk.encoding.containsCStringNullBytesBeforeStringEnding() else {
                throw RustWeldingError.invalidInput(message: "`UFVK` contains null bytes.")
            }
            
            guard self.isValidUnifiedFullViewingKey(ufvk.encoding, networkType: networkType) else {
                throw RustWeldingError.invalidInput(message: "UFVK is invalid.")
            }

            let ufvkCStr = [CChar](String(ufvk.encoding).utf8CString)
            
            let ufvkPtr = UnsafeMutablePointer<CChar>.allocate(capacity: ufvkCStr.count)
            ufvkPtr.initialize(from: ufvkCStr, count: ufvkCStr.count)

            ffiUfvks.append(
                FFIEncodedKey(account_id: ufvk.account, encoding: ufvkPtr)
            )
        }

        var contiguousUVKs = ContiguousArray(ffiUfvks)

        var result = false

        contiguousUVKs.withContiguousMutableStorageIfAvailable { ufvksPtr in
            result = zcashlc_init_accounts_table_with_keys(
                dbData.0,
                dbData.1,
                ufvksPtr.baseAddress,
                UInt(ufvks.count),
                networkType.networkId
            )
        }

        defer {
            for ufvk in ffiUfvks {
                ufvk.encoding.deallocate()
            }
        }

        guard result else {
            throw lastError() ?? .genericError(message: "`initAccountsTable` failed with unknown error")
        }
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
            throw RustWeldingError.invalidInput(message: "`hash` contains null bytes.")
        }
        
        guard !saplingTree.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.invalidInput(message: "`saplingTree` contains null bytes.")
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
            throw lastError() ?? .genericError(message: "No error message available")
        }
    }

    static func listTransparentReceivers(
        dbData: URL,
        account: Int32,
        networkType: NetworkType
    ) throws -> [TransparentAddress] {
        let dbData = dbData.osStr()

        guard let encodedKeysPtr = zcashlc_list_transparent_receivers(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        ) else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        defer { zcashlc_free_keys(encodedKeysPtr) }

        var addresses = [TransparentAddress]()

        for i in (0 ..< Int(encodedKeysPtr.pointee.len)) {
            let key = encodedKeysPtr.pointee.ptr.advanced(by: i).pointee

            guard let taddrStr = String(validatingUTF8: key.encoding) else {
                throw RustWeldingError.unableToDeriveKeys
            }

            addresses.append(
                TransparentAddress(validatedEncoding: taddrStr)
            )
        }

        return addresses
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
            throw lastError() ?? .genericError(message: "No error message available")
        }

        return true
    }
    
    static func validateCombinedChain(dbCache: URL, dbData: URL, networkType: NetworkType) -> Int32 {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_validate_combined_chain(dbCache.0, dbCache.1, dbData.0, dbData.1, networkType.networkId)
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
    
    static func shieldFunds(
        dbCache: URL,
        dbData: URL,
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 {
        let dbData = dbData.osStr()

        return usk.bytes.withUnsafeBufferPointer { uskBuffer in
            zcashlc_shield_funds(
                dbData.0,
                dbData.1,
                uskBuffer.baseAddress,
                UInt(usk.bytes.count),
                memo?.bytes,
                spendParamsPath,
                UInt(spendParamsPath.lengthOfBytes(using: .utf8)),
                outputParamsPath,
                UInt(outputParamsPath.lengthOfBytes(using: .utf8)),
                networkType.networkId,
                useZIP317Fees
            )
        }
    }
    
    static func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey, networkType: NetworkType) throws -> UnifiedFullViewingKey {

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


    static func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32] {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.invalidInput(message: "`address` contains null bytes.")
        }

        var len = UInt(0)

        guard let typecodesPointer =  zcashlc_get_typecodes_for_unified_address_receivers(
            [CChar](address.utf8CString),
            &len
          ),
            len > 0
              else {
            throw RustWeldingError.malformedStringInput
        }

        var typecodes = [UInt32]()

        for typecodeIndex in 0 ..< Int(len) {
            let pointer = typecodesPointer.advanced(by: typecodeIndex)

            typecodes.append(pointer.pointee)
        }

        defer {
            zcashlc_free_typecodes(typecodesPointer, len)
        }

        return typecodes
    }
    
    static func consensusBranchIdFor(height: Int32, networkType: NetworkType) throws -> Int32 {
        let branchId = zcashlc_branch_id_for_height(height, networkType.networkId)
        
        guard branchId != -1 else {
            throw RustWeldingError.noConsensusBranchId(height: height)
        }
        
        return branchId
    }
}

private extension ZcashRustBackend {
    static func throwDataDbError(_ error: RustWeldingError) -> Error {
        if case RustWeldingError.genericError(let message) = error, message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }

        return RustWeldingError.dataDbInitFailed(message: error.localizedDescription)
    }

    static func throwBalanceError(account: Int32, _ error: RustWeldingError?, fallbackMessage: String) -> Error {
        guard let balanceError = error else {
            return RustWeldingError.genericError(message: fallbackMessage)
        }

        return RustWeldingError.getBalanceError(Int(account), balanceError)
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

extension FFIBinaryKey {
    /// converts an [`FFIBinaryKey`] into a [`UnifiedSpendingKey`]
    /// - Note: This does not check that the converted value actually holds a valid USK
    func unsafeToUnifiedSpendingKey(network: NetworkType) -> UnifiedSpendingKey {
        .init(
            network: network,
            bytes: self.encoding.toByteArray(
                length: Int(self.encoding_len)),
            account: self.account_id
        )
    }
}

extension UnsafeMutablePointer where Pointee == UInt8 {
    /// copies the bytes pointed on
    func toByteArray(length: Int) -> [UInt8] {
        var bytes = [UInt8]()

        for index in 0 ..< length {
            bytes.append(self.advanced(by: index).pointee)
        }

        return bytes
    }
}
    

extension RustWeldingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .genericError(let message):
            return "RustWeldingError generic error: \(message)"
        case .dataDbInitFailed(let message):
            return "`RustWeldingError.dataDbInitFailed` with message: \(message)"
        case .dataDbNotEmpty:
            return "`.DataDbNotEmpty`. This is usually not an error."
        case .invalidInput(let message):
            return "`RustWeldingError.invalidInput` with message: \(message)"
        case .malformedStringInput:
            return "`.malformedStringInput` Called a function with a malformed string input."
        case .invalidRewind:
            return "`.invalidRewind` called the rewind API with an arbitrary height that is not valid."
        case .noConsensusBranchId(let branchId):
            return "`.noConsensusBranchId` number \(branchId)"
        case .saplingSpendParametersNotFound:
            return "`.saplingSpendParametersNotFound` sapling parameters not present at specified URL"
        case .unableToDeriveKeys:
            return "`.unableToDeriveKeys` the requested keys could not be derived from the source provided"
        case .getBalanceError(let account, let error):
            return "`.getBalanceError` could not retrieve balance from account: \(account), error:\(error)"
        }
    }
}
