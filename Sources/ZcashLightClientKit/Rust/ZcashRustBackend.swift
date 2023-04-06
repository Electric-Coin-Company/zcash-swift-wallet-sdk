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

actor ZcashRustBackend: ZcashRustBackendWelding {
    let minimumConfirmations: UInt32 = 10
    let useZIP317Fees = false

    let dbData: (String, UInt)
    let fsBlockDbRoot: (String, UInt)
    let spendParamsPath: (String, UInt)
    let outputParamsPath: (String, UInt)
    let keyDeriving: ZcashKeyDeriving

    nonisolated let networkType: NetworkType

    /// Creates instance of `ZcashRustBackend`.
    /// - Parameters:
    ///   - dbData: `URL` pointing to file where data database will be.
    ///   - fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    ///                    this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    ///                    format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    ///   - spendParamsPath: `URL` pointing to spend parameters file.
    ///   - outputParamsPath: `URL` pointing to output parameters file.
    ///   - networkType: Network type to use.
    init(dbData: URL, fsBlockDbRoot: URL, spendParamsPath: URL, outputParamsPath: URL, networkType: NetworkType) {
        self.dbData = dbData.osStr()
        self.fsBlockDbRoot = fsBlockDbRoot.osPathStr()
        self.spendParamsPath = spendParamsPath.osPathStr()
        self.outputParamsPath = outputParamsPath.osPathStr()
        self.networkType = networkType
        self.keyDeriving = ZcashKeyDerivationBackend(networkType: networkType)
    }

    func createAccount(seed: [UInt8]) async throws -> UnifiedSpendingKey {
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

    func createToAddress(
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?
    ) async throws -> Int64 {
        let result = usk.bytes.withUnsafeBufferPointer { uskPtr in
            zcashlc_create_to_address(
                dbData.0,
                dbData.1,
                uskPtr.baseAddress,
                UInt(usk.bytes.count),
                [CChar](address.utf8CString),
                value,
                memo?.bytes,
                spendParamsPath.0,
                spendParamsPath.1,
                outputParamsPath.0,
                outputParamsPath.1,
                networkType.networkId,
                minimumConfirmations,
                useZIP317Fees
            )
        }

        guard result > 0 else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        return result
    }

    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws {
        let result = zcashlc_decrypt_and_store_transaction(
            dbData.0,
            dbData.1,
            txBytes,
            UInt(txBytes.count),
            UInt32(minedHeight),
            networkType.networkId
        )

        guard result != 0 else {
            throw lastError() ?? .genericError(message: "No error message available")
        }
    }

    func getBalance(account: Int32) async throws -> Int64 {
        let balance = zcashlc_get_balance(dbData.0, dbData.1, account, networkType.networkId)

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage: "Error getting total balance from account \(account)")
        }

        return balance
    }

    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress {
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

    func getNearestRewindHeight(height: Int32) async throws -> Int32 {
        let result = zcashlc_get_nearest_rewind_height(
            dbData.0,
            dbData.1,
            height,
            networkType.networkId
        )

        guard result > 0 else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        return result
    }

    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress {
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

    func getReceivedMemo(idNote: Int64) async -> Memo? {
        var contiguousMemoBytes = ContiguousArray<UInt8>(MemoBytes.empty().bytes)
        var success = false

        contiguousMemoBytes.withUnsafeMutableBufferPointer { memoBytePtr in
            success = zcashlc_get_received_memo(dbData.0, dbData.1, idNote, memoBytePtr.baseAddress, networkType.networkId)
        }

        guard success else { return nil }

        return (try? MemoBytes(contiguousBytes: contiguousMemoBytes)).flatMap { try? $0.intoMemo() }
    }

    func getSentMemo(idNote: Int64) async -> Memo? {
        var contiguousMemoBytes = ContiguousArray<UInt8>(MemoBytes.empty().bytes)
        var success = false

        contiguousMemoBytes.withUnsafeMutableBytes { memoBytePtr in
            success = zcashlc_get_sent_memo(dbData.0, dbData.1, idNote, memoBytePtr.baseAddress, networkType.networkId)
        }

        guard success else { return nil }

        return (try? MemoBytes(contiguousBytes: contiguousMemoBytes)).flatMap { try? $0.intoMemo() }
    }

    func getTransparentBalance(account: Int32) async throws -> Int64 {
        guard account >= 0 else {
            throw RustWeldingError.invalidInput(message: "Account index must be non-negative")
        }

        let balance = zcashlc_get_total_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account
        )

        guard balance >= 0 else {
            throw throwBalanceError(account: account, lastError(), fallbackMessage: "Error getting Total Transparent balance from account \(account)")
        }

        return balance
    }

    func getVerifiedBalance(account: Int32) async throws -> Int64 {
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

    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64 {
        guard account >= 0 else {
            throw RustWeldingError.invalidInput(message: "`account` must be non-negative")
        }

        let balance = zcashlc_get_verified_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account,
            minimumConfirmations
        )

        guard balance >= 0 else {
            throw throwBalanceError(
                account: account,
                lastError(),
                fallbackMessage: "Error getting verified transparent balance from account \(account)"
            )
        }

        return balance
    }

    private nonisolated func lastError() -> RustWeldingError? {
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

    private nonisolated func getLastError() -> String? {
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

    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult {
        switch zcashlc_init_data_database(dbData.0, dbData.1, seed, UInt(seed?.count ?? 0), networkType.networkId) {
        case 0: // ok
            return DbInitResult.success
        case 1:
            return DbInitResult.seedRequired
        default:
            throw throwDataDbError(lastError() ?? .genericError(message: "No error message found"))
        }
    }

    func initAccountsTable(ufvks: [UnifiedFullViewingKey]) async throws {
        var ffiUfvks: [FFIEncodedKey] = []
        for ufvk in ufvks {
            guard !ufvk.encoding.containsCStringNullBytesBeforeStringEnding() else {
                throw RustWeldingError.invalidInput(message: "`UFVK` contains null bytes.")
            }

            guard self.keyDeriving.isValidUnifiedFullViewingKey(ufvk.encoding) else {
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

    func initBlockMetadataDb() async throws {
        let result = zcashlc_init_block_metadata_db(fsBlockDbRoot.0, fsBlockDbRoot.1)

        guard result else {
            throw lastError() ?? .genericError(message: "`initAccountsTable` failed with unknown error")
        }
    }

    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws {
        var ffiBlockMetaVec: [FFIBlockMeta] = []

        for block in blocks {
            let meta = block.meta
            let hashPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: meta.hash.count)

            let contiguousHashBytes = ContiguousArray(meta.hash.bytes)

            let result: Void? = contiguousHashBytes.withContiguousStorageIfAvailable { hashBytesPtr in
                // swiftlint:disable:next force_unwrapping
                hashPtr.initialize(from: hashBytesPtr.baseAddress!, count: hashBytesPtr.count)
            }

            guard result != nil else {
                defer {
                    hashPtr.deallocate()
                    ffiBlockMetaVec.deallocateElements()
                }
                throw RustWeldingError.writeBlocksMetadataAllocationProblem
            }

            ffiBlockMetaVec.append(
                FFIBlockMeta(
                    height: UInt32(block.height),
                    block_hash_ptr: hashPtr,
                    block_hash_ptr_len: UInt(contiguousHashBytes.count),
                    block_time: meta.time,
                    sapling_outputs_count: meta.saplingOutputs,
                    orchard_actions_count: meta.orchardOutputs
                )
            )
        }

        var contiguousFFIBlocks = ContiguousArray(ffiBlockMetaVec)

        let len = UInt(contiguousFFIBlocks.count)

        let fsBlocks = UnsafeMutablePointer<FFIBlocksMeta>.allocate(capacity: 1)

        defer { ffiBlockMetaVec.deallocateElements() }

        try contiguousFFIBlocks.withContiguousMutableStorageIfAvailable { ptr in
            var meta = FFIBlocksMeta()
            meta.ptr = ptr.baseAddress
            meta.len = len

            fsBlocks.initialize(to: meta)

            let res = zcashlc_write_block_metadata(fsBlockDbRoot.0, fsBlockDbRoot.1, fsBlocks)

            guard res else {
                throw lastError() ?? RustWeldingError.genericError(message: "failed to write block metadata")
            }
        }
    }

    func initBlocksTable(
        height: Int32,
        hash: String,
        time: UInt32,
        saplingTree: String
    ) async throws {
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

    func latestCachedBlockHeight() async -> BlockHeight {
        return BlockHeight(zcashlc_latest_cached_block_height(fsBlockDbRoot.0, fsBlockDbRoot.1))
    }

    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress] {
        guard let encodedKeysPtr = zcashlc_list_transparent_receivers(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        ) else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        defer { zcashlc_free_keys(encodedKeysPtr) }

        var addresses: [TransparentAddress] = []

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

    func putUnspentTransparentOutput(
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight
    ) async throws {
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
    }

    func validateCombinedChain(limit: UInt32 = 0) async throws {
        let result = zcashlc_validate_combined_chain(fsBlockDbRoot.0, fsBlockDbRoot.1, dbData.0, dbData.1, networkType.networkId, limit)

        switch result {
        case -1:
            return
        case 0:
            throw RustWeldingError.chainValidationFailed(message: getLastError())
        default:
            throw RustWeldingError.invalidChain(upperBound: result)
        }
    }

    func rewindToHeight(height: Int32) async throws {
        let result = zcashlc_rewind_to_height(dbData.0, dbData.1, height, networkType.networkId)

        guard result else {
            throw lastError() ?? .genericError(message: "No error message available")
        }
    }

    func rewindCacheToHeight(height: Int32) async throws {
        let result = zcashlc_rewind_fs_block_cache_to_height(fsBlockDbRoot.0, fsBlockDbRoot.1, height)

        guard result else {
            throw lastError() ?? .genericError(message: "No error message available")
        }
    }

    func scanBlocks(limit: UInt32 = 0) async throws {
        let result = zcashlc_scan_blocks(fsBlockDbRoot.0, fsBlockDbRoot.1, dbData.0, dbData.1, limit, networkType.networkId)

        guard result != 0 else {
            throw lastError() ?? .genericError(message: "No error message available")
        }
    }

    func shieldFunds(
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        shieldingThreshold: Zatoshi
    ) async throws -> Int64 {
        let result = usk.bytes.withUnsafeBufferPointer { uskBuffer in
            zcashlc_shield_funds(
                dbData.0,
                dbData.1,
                uskBuffer.baseAddress,
                UInt(usk.bytes.count),
                memo?.bytes,
                UInt64(shieldingThreshold.amount),
                spendParamsPath.0,
                spendParamsPath.1,
                outputParamsPath.0,
                outputParamsPath.1,
                networkType.networkId,
                minimumConfirmations,
                useZIP317Fees
            )
        }

        guard result > 0 else {
            throw lastError() ?? .genericError(message: "No error message available")
        }

        return result
    }

    nonisolated func consensusBranchIdFor(height: Int32) throws -> Int32 {
        let branchId = zcashlc_branch_id_for_height(height, networkType.networkId)

        guard branchId != -1 else {
            throw RustWeldingError.noConsensusBranchId(height: height)
        }

        return branchId
    }
}

private extension ZcashRustBackend {
    func throwDataDbError(_ error: RustWeldingError) -> Error {
        if case RustWeldingError.genericError(let message) = error, message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }

        return RustWeldingError.dataDbInitFailed(message: error.localizedDescription)
    }

    func throwBalanceError(account: Int32, _ error: RustWeldingError?, fallbackMessage: String) -> Error {
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

    /// use when the rust ffi needs to make filesystem operations
    func osPathStr() -> (String, UInt) {
        let path = self.path
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
                length: Int(self.encoding_len)
            ),
            account: self.account_id
        )
    }
}

extension UnsafeMutablePointer where Pointee == UInt8 {
    /// copies the bytes pointed on
    func toByteArray(length: Int) -> [UInt8] {
        var bytes: [UInt8] = []

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
        case let .getBalanceError(account, error):
            return "`.getBalanceError` could not retrieve balance from account: \(account), error:\(error)"
        case let .invalidChain(upperBound: upperBound):
            return "`.validateCombinedChain` failed to validate chain. Upper bound: \(upperBound)."
        case let .chainValidationFailed(message):
            return """
            `.validateCombinedChain` failed to validate chain because of error unrelated to chain validity. \
            Message: \(String(describing: message))
            """
        case .writeBlocksMetadataAllocationProblem:
            return "`.writeBlocksMetadata` failed to allocate memory on Swift side necessary to write blocks metadata to db."
        }
    }
}

extension Array where Element == FFIBlockMeta {
    func deallocateElements() {
        self.forEach { element in
            element.block_hash_ptr.deallocate()
        }
    }
}
