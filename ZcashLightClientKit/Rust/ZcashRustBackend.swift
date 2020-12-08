//
//  ZcashRustBackend.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class ZcashRustBackend: ZcashRustBackendWelding {
    
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
    static func initDataDb(dbData: URL) throws {
        let dbData = dbData.osStr()
        guard zcashlc_init_data_database(dbData.0, dbData.1) != 0 else {
            if let error = lastError() {
                throw throwDataDbError(error)
            }
            throw RustWeldingError.dataDbInitFailed(message: "unknown error")
        }
    }
    
    static func isValidShieldedAddress(_ address: String) throws -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }
        
        guard zcashlc_is_valid_shielded_address([CChar](address.utf8CString)) else {
            if let error = lastError() {
                throw error
            }
            return false
        }
        return true
    }
    
    static func isValidTransparentAddress(_ address: String) throws -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
                   return false
        }
        
        guard zcashlc_is_valid_transparent_address([CChar](address.utf8CString)) else {
            if let error = lastError() {
                throw error
            }
            return false
        }
        return true
    }
    
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]? {
        let dbData = dbData.osStr()
        var capacity = UInt(0);
        let extsksCStr = zcashlc_init_accounts_table(dbData.0, dbData.1, seed, UInt(seed.count), accounts, &capacity)
        if extsksCStr == nil {
            return nil
        }
        
        let extsks = UnsafeBufferPointer(start: extsksCStr, count: Int(accounts)).compactMap({ (cStr) -> String? in
            guard let str = cStr else { return nil }
            return String(cString: str)
        })
        zcashlc_vec_string_free(extsksCStr, UInt(accounts), capacity)
        return extsks
    }
    
    static func initAccountsTable(dbData: URL, exfvks: [String]) throws -> Bool {
        let dbData = dbData.osStr()
        let viewingKeys = exfvks.map { UnsafePointer(strdup($0)) }
        
        guard exfvks.count > 0 else {
            throw RustWeldingError.malformedStringInput
        }
        
        let res = zcashlc_init_accounts_table_with_keys(dbData.0, dbData.1, viewingKeys, UInt(viewingKeys.count));
        
        viewingKeys.compactMap({ UnsafeMutablePointer(mutating: $0) }).forEach({ free($0) })
        
        guard res else {
            if let error = lastError() {
                throw error
            }
            return false
        }
        return res
        
    }
    
    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String) throws {
        let dbData = dbData.osStr()
        
        guard !hash.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard !saplingTree.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard zcashlc_init_blocks_table(dbData.0, dbData.1, height, [CChar](hash.utf8CString), time, [CChar](saplingTree.utf8CString)) != 0 else {
            if let error = lastError() {
                throw error
            }
            throw RustWeldingError.dataDbInitFailed(message: "Unknown Error")
        }
    }
    
    static func getAddress(dbData: URL, account: Int32) -> String? {
        let dbData = dbData.osStr()
        
        guard let addressCStr = zcashlc_get_address(dbData.0, dbData.1, account) else { return nil }
        
        let address = String(validatingUTF8: addressCStr)
        zcashlc_string_free(addressCStr)
        return address
    }
    
    static func getBalance(dbData: URL, account: Int32) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_balance(dbData.0, dbData.1, account)
    }
    
    static func getVerifiedBalance(dbData: URL, account: Int32) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_verified_balance(dbData.0, dbData.1, account)
    }
    
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        let dbData = dbData.osStr()
        
        guard let memoCStr = zcashlc_get_received_memo_as_utf8(dbData.0, dbData.1, idNote) else { return  nil }
        
        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }
    
    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        let dbData = dbData.osStr()
        
        guard let memoCStr = zcashlc_get_sent_memo_as_utf8(dbData.0, dbData.1, idNote) else { return nil }
        
        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }
    
    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32 {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_validate_combined_chain(dbCache.0, dbCache.1, dbData.0, dbData.1)
    }
    
    static func rewindToHeight(dbData: URL, height: Int32) -> Bool {
        let dbData = dbData.osStr()
        return zcashlc_rewind_to_height(dbData.0, dbData.1, height) != 0
    }
    
    static func scanBlocks(dbCache: URL, dbData: URL) -> Bool {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_scan_blocks(dbCache.0, dbCache.1, dbData.0, dbData.1) != 0
    }

    static func decryptAndStoreTransaction(dbData: URL, tx: [UInt8]) -> Bool {
        let dbData = dbData.osStr()
        return zcashlc_decrypt_and_store_transaction(dbData.0, dbData.1, tx, UInt(tx.count)) != 0
    }

    static func createToAddress(dbData: URL, account: Int32, extsk: String, consensusBranchId: Int32,to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String) -> Int64 {
        let dbData = dbData.osStr()
        let memoBytes = memo ?? ""
        
        return zcashlc_create_to_address(dbData.0,
                                         dbData.1,
                                         account,
                                         extsk,
                                         to,
                                         value,
                                         memoBytes,
                                         spendParamsPath,
                                         UInt(spendParamsPath.lengthOfBytes(using: .utf8)),
                                         outputParamsPath,
                                         UInt(outputParamsPath.lengthOfBytes(using: .utf8)))
    }
    
    static func deriveExtendedFullViewingKey(_ spendingKey: String) throws -> String? {
        
        guard !spendingKey.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard let extsk = zcashlc_derive_extended_full_viewing_key([CChar](spendingKey.utf8CString)) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        
        let derived = String(validatingUTF8: extsk)
        
        zcashlc_string_free(extsk)
        return derived
    }
    
    static func deriveExtendedFullViewingKeys(seed: [UInt8], accounts: Int32) throws -> [String]? {
        var capacity = UInt(0);
        guard let extsksCStr = zcashlc_derive_extended_full_viewing_keys(seed, UInt(seed.count), accounts, &capacity) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        
        let extsks = UnsafeBufferPointer(start: extsksCStr, count: Int(accounts)).compactMap({ (cStr) -> String? in
            guard let str = cStr else { return nil }
            return String(cString: str)
        })
        zcashlc_vec_string_free(extsksCStr, UInt(accounts), capacity)
        return extsks
    }
    
    static func deriveExtendedSpendingKeys(seed: [UInt8], accounts: Int32) throws -> [String]? {
        var capacity = UInt(0);
        guard let extsksCStr = zcashlc_derive_extended_spending_keys(seed, UInt(seed.count), accounts, &capacity) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        
        let extsks = UnsafeBufferPointer(start: extsksCStr, count: Int(accounts)).compactMap({ (cStr) -> String? in
            guard let str = cStr else { return nil }
            return String(cString: str)
        })
        zcashlc_vec_string_free(extsksCStr, UInt(accounts), capacity)
        return extsks
    }
    
    static func deriveShieldedAddressFromSeed(seed: [UInt8], accountIndex: Int32) throws -> String? {
        guard let zaddrCStr = zcashlc_derive_shielded_address_from_seed(seed, UInt(seed.count), accountIndex) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        let zAddr = String(validatingUTF8: zaddrCStr)
        
        zcashlc_string_free(zaddrCStr)
        
        return zAddr
    }
    
    static func deriveShieldedAddressFromViewingKey(_ extfvk: String) throws -> String? {
        guard !extfvk.containsCStringNullBytesBeforeStringEnding() else {
            throw RustWeldingError.malformedStringInput
        }
        
        guard let zaddrCStr = zcashlc_derive_shielded_address_from_viewing_key([CChar](extfvk.utf8CString)) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        let zAddr = String(validatingUTF8: zaddrCStr)
        
        zcashlc_string_free(zaddrCStr)
        
        return zAddr
    }
    
    static func deriveTransparentAddressFromSeed(seed: [UInt8]) throws -> String? {
        
        guard let tAddrCStr = zcashlc_derive_transparent_address_from_seed(seed, UInt(seed.count)) else {
            if let error = lastError() {
                throw error
            }
            return nil
        }
        
        let tAddr = String(validatingUTF8: tAddrCStr)
        
        return tAddr
    }
    
    static func consensusBranchIdFor(height: Int32) throws -> Int32 {
        let branchId = zcashlc_branch_id_for_height(height)
        
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
