//
//  Stubs.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import SwiftProtobuf
@testable import ZcashLightClientKit

// swiftlint:disable function_parameter_count identifier_name
class AwfulLightWalletService: MockLightWalletService {
    override func latestBlockHeight() throws -> BlockHeight {
        throw LightWalletServiceError.criticalError
    }
    
    override func latestBlockHeightAsync() async throws -> BlockHeight {
        throw LightWalletServiceError.invalidBlock
    }
    
    override func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: LightWalletServiceError.invalidBlock) }
    }

    /// Submits a raw transaction over lightwalletd.
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        throw LightWalletServiceError.invalidBlock
    }
}

extension LightWalletServiceMockResponse: Error { }

class SlightlyBadLightWalletService: MockLightWalletService {
    /// Submits a raw transaction over lightwalletd.
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        throw LightWalletServiceMockResponse.error
    }
}

extension LightWalletServiceMockResponse {
    static var error: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(
            errorCode: -100,
            errorMessage: "Ohhh this is bad, really bad, you lost all your internet money",
            unknownFields: UnknownStorage()
        )
    }

    static var success: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())
    }
}

class MockRustBackend: ZcashRustBackendWelding {
    static func initAccountsTable(dbData: URL, ufvks: [ZcashLightClientKit.UnifiedFullViewingKey], networkType: ZcashLightClientKit.NetworkType) throws {
        
    }

    static func createToAddress(dbData: URL, usk: ZcashLightClientKit.UnifiedSpendingKey, to address: String, value: Int64, memo: ZcashLightClientKit.MemoBytes?, spendParamsPath: String, outputParamsPath: String, networkType: ZcashLightClientKit.NetworkType) -> Int64 {
        -1
    }

    static func shieldFunds(dbCache: URL, dbData: URL, usk: ZcashLightClientKit.UnifiedSpendingKey, memo: ZcashLightClientKit.MemoBytes?, spendParamsPath: String, outputParamsPath: String, networkType: ZcashLightClientKit.NetworkType) -> Int64 {
        -1
    }

    static func getAddressMetadata(_ address: String) -> ZcashLightClientKit.AddressMetadata? {
        nil
    }
    
    static func clearUtxos(dbData: URL, address: ZcashLightClientKit.TransparentAddress, sinceHeight: ZcashLightClientKit.BlockHeight, networkType: ZcashLightClientKit.NetworkType) throws -> Int32 {
        0
    }

    static func getTransparentBalance(dbData: URL, account: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> Int64 {
         0
    }

    static func getVerifiedTransparentBalance(dbData: URL, account: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> Int64 {
        0
    }

    static func listTransparentReceivers(dbData: URL, account: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> [ZcashLightClientKit.TransparentAddress] {
        []
    }

    static func deriveUnifiedFullViewingKey(from spendingKey: ZcashLightClientKit.UnifiedSpendingKey, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.UnifiedFullViewingKey {
        throw KeyDerivationErrors.unableToDerive
    }

    static func deriveUnifiedSpendingKey(from seed: [UInt8], accountIndex: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.UnifiedSpendingKey {
        throw KeyDerivationErrors.unableToDerive
    }

    static func getCurrentAddress(dbData: URL, account: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.UnifiedAddress {
        throw KeyDerivationErrors.unableToDerive
    }

    static func getNextAvailableAddress(dbData: URL, account: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.UnifiedAddress {
        throw KeyDerivationErrors.unableToDerive
    }

    static func getSaplingReceiver(for uAddr: ZcashLightClientKit.UnifiedAddress) throws -> ZcashLightClientKit.SaplingAddress? {
        throw KeyDerivationErrors.unableToDerive
    }

    static func getTransparentReceiver(for uAddr: ZcashLightClientKit.UnifiedAddress) throws -> ZcashLightClientKit.TransparentAddress? {
        throw KeyDerivationErrors.unableToDerive
    }

    static func shieldFunds(dbCache: URL, dbData: URL, usk: ZcashLightClientKit.UnifiedSpendingKey, memo: ZcashLightClientKit.MemoBytes, spendParamsPath: String, outputParamsPath: String, networkType: ZcashLightClientKit.NetworkType) -> Int64 {
        -1
    }

    static func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32] {
        throw KeyDerivationErrors.receiverNotFound
    }

    static func createAccount(dbData: URL, seed: [UInt8], networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.UnifiedSpendingKey {
        throw KeyDerivationErrors.unableToDerive
    }

    static func getReceivedMemo(dbData: URL, idNote: Int64, networkType: ZcashLightClientKit.NetworkType) -> ZcashLightClientKit.Memo? {
        nil
    }

    static func getSentMemo(dbData: URL, idNote: Int64, networkType: ZcashLightClientKit.NetworkType) -> ZcashLightClientKit.Memo? {
        nil
    }

    static func createToAddress(dbData: URL, usk: ZcashLightClientKit.UnifiedSpendingKey, to address: String, value: Int64, memo: ZcashLightClientKit.MemoBytes, spendParamsPath: String, outputParamsPath: String, networkType: ZcashLightClientKit.NetworkType) -> Int64 {
        -1
    }

    static func initDataDb(dbData: URL, seed: [UInt8]?, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.DbInitResult {
        .seedRequired
    }

    static func deriveSaplingAddressFromViewingKey(_ extfvk: ZcashLightClientKit.SaplingExtendedFullViewingKey, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.SaplingAddress {
        throw RustWeldingError.unableToDeriveKeys
    }

    static func isValidSaplingExtendedSpendingKey(_ key: String, networkType: ZcashLightClientKit.NetworkType) -> Bool {
        false
    }

    static func deriveSaplingExtendedFullViewingKeys(seed: [UInt8], accounts: Int32, networkType: ZcashLightClientKit.NetworkType) throws -> [ZcashLightClientKit.SaplingExtendedFullViewingKey]? {
        nil
    }

    static func isValidUnifiedAddress(_ address: String, networkType: ZcashLightClientKit.NetworkType) -> Bool {
        false
    }

    static func deriveSaplingExtendedFullViewingKey(_ spendingKey: SaplingExtendedSpendingKey, networkType: ZcashLightClientKit.NetworkType) throws -> ZcashLightClientKit.SaplingExtendedFullViewingKey? {
        nil
    }


    public func deriveViewingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedFullViewingKey] {
        []
    }
    
    static func getNearestRewindHeight(dbData: URL, height: Int32, networkType: NetworkType) -> Int32 {
        -1
    }
    
    static func network(dbData: URL, address: String, sinceHeight: BlockHeight, networkType: NetworkType) throws -> Int32 {
        -1
    }
    
    static func initAccountsTable(dbData: URL, ufvks: [UnifiedFullViewingKey], networkType: NetworkType) throws -> Bool {
        false
    }
    
    static func putUnspentTransparentOutput(
        dbData: URL,
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight,
        networkType: NetworkType
    ) throws -> Bool {
        false
    }
    
    static func downloadedUtxoBalance(dbData: URL, address: String, networkType: NetworkType) throws -> WalletBalance {
        throw RustWeldingError.genericError(message: "unimplemented")
    }
    
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
        -1
    }

    static func deriveTransparentAddressFromSeed(seed: [UInt8], account: Int, index: Int, networkType: NetworkType) throws -> TransparentAddress {
        throw KeyDerivationErrors.unableToDerive
    }

    static func deriveUnifiedFullViewingKeyFromSeed(_ seed: [UInt8], numberOfAccounts: Int32, networkType: NetworkType) throws -> [UnifiedFullViewingKey] {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func isValidSaplingExtendedFullViewingKey(_ key: String, networkType: NetworkType) -> Bool {
        false
    }
    
    static func isValidUnifiedFullViewingKey(_ ufvk: String, networkType: NetworkType) -> Bool {
        false
    }

    static func deriveSaplingExtendedSpendingKeys(seed: [UInt8], accounts: Int32, networkType: NetworkType) throws -> [SaplingExtendedSpendingKey]? {
        nil
    }

    static func consensusBranchIdFor(height: Int32, networkType: NetworkType) throws -> Int32 {
        guard let consensus = consensusBranchID else {
            return try rustBackend.consensusBranchIdFor(height: height, networkType: networkType)
        }
        return consensus
    }
    
    static var networkType = NetworkType.testnet
    static var mockDataDb = false
    static var mockAcounts = false
    static var mockError: RustWeldingError?
    static var mockLastError: String?
    static var mockAccounts: [SaplingExtendedSpendingKey]?
    static var mockAddresses: [String]?
    static var mockBalance: Int64?
    static var mockVerifiedBalance: Int64?
    static var mockMemo: String?
    static var mockSentMemo: String?
    static var mockValidateCombinedChainSuccessRate: Float?
    static var mockValidateCombinedChainFailAfterAttempts: Int?
    static var mockValidateCombinedChainKeepFailing = false
    static var mockValidateCombinedChainFailureHeight: BlockHeight = 0
    static var mockScanblocksSuccessRate: Float?
    static var mockCreateToAddress: Int64?
    static var rustBackend = ZcashRustBackend.self
    static var consensusBranchID: Int32?
    
    static func lastError() -> RustWeldingError? {
        mockError ?? rustBackend.lastError()
    }
    
    static func getLastError() -> String? {
        mockLastError ?? rustBackend.getLastError()
    }
    
    static func isValidSaplingAddress(_ address: String, networkType: NetworkType) -> Bool {
        true
    }
    
    static func isValidTransparentAddress(_ address: String, networkType: NetworkType) -> Bool {
        true
    }
    
    static func initDataDb(dbData: URL, networkType: NetworkType) throws {
        if !mockDataDb {
            _ = try rustBackend.initDataDb(dbData: dbData, seed: nil, networkType: networkType)
        }
    }

    static func initBlocksTable(
        dbData: URL,
        height: Int32,
        hash: String,
        time: UInt32,
        saplingTree: String,
        networkType: NetworkType
    ) throws {
        if !mockDataDb {
            try rustBackend.initBlocksTable(
                dbData: dbData,
                height: height,
                hash: hash,
                time: time,
                saplingTree: saplingTree,
                networkType: networkType
            )
        }
    }
    
    static func getBalance(dbData: URL, account: Int32, networkType: NetworkType) throws -> Int64 {
        if let balance = mockBalance {
            return balance
        }
        return try rustBackend.getBalance(dbData: dbData, account: account, networkType: networkType)
    }
    
    static func getVerifiedBalance(dbData: URL, account: Int32, networkType: NetworkType) throws -> Int64 {
        if let balance = mockVerifiedBalance {
            return balance
        }

        return try rustBackend.getVerifiedBalance(dbData: dbData, account: account, networkType: networkType)
    }
    
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64, networkType: NetworkType) -> String? {
        mockMemo ?? rustBackend.getReceivedMemoAsUTF8(dbData: dbData, idNote: idNote, networkType: networkType)
    }
    
    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64, networkType: NetworkType) -> String? {
        mockSentMemo ?? getSentMemoAsUTF8(dbData: dbData, idNote: idNote, networkType: networkType)
    }
    
    static func validateCombinedChain(dbCache: URL, dbData: URL, networkType: NetworkType) -> Int32 {
        if let rate = self.mockValidateCombinedChainSuccessRate {
            if shouldSucceed(successRate: rate) {
                return validationResult(dbCache: dbCache, dbData: dbData, networkType: networkType)
            } else {
                return Int32(mockValidateCombinedChainFailureHeight)
            }
        } else if let attempts = self.mockValidateCombinedChainFailAfterAttempts {
            self.mockValidateCombinedChainFailAfterAttempts = attempts - 1
            if attempts > 0 {
                return validationResult(dbCache: dbCache, dbData: dbData, networkType: networkType)
            } else {
                if attempts == 0 {
                    return Int32(mockValidateCombinedChainFailureHeight)
                } else if attempts < 0 && mockValidateCombinedChainKeepFailing {
                    return Int32(mockValidateCombinedChainFailureHeight)
                } else {
                    return validationResult(dbCache: dbCache, dbData: dbData, networkType: networkType)
                }
            }
        }
        return rustBackend.validateCombinedChain(dbCache: dbCache, dbData: dbData, networkType: networkType)
    }
    
    private static func validationResult(dbCache: URL, dbData: URL, networkType: NetworkType) -> Int32 {
        if mockDataDb {
            return -1
        } else {
            return rustBackend.validateCombinedChain(dbCache: dbCache, dbData: dbData, networkType: networkType)
        }
    }
    
    static func rewindToHeight(dbData: URL, height: Int32, networkType: NetworkType) -> Bool {
        mockDataDb ? true : rustBackend.rewindToHeight(dbData: dbData, height: height, networkType: networkType)
    }
    
    static func scanBlocks(dbCache: URL, dbData: URL, limit: UInt32, networkType: NetworkType) -> Bool {
        if let rate = mockScanblocksSuccessRate {
            if shouldSucceed(successRate: rate) {
                return mockDataDb ? true : rustBackend.scanBlocks(dbCache: dbCache, dbData: dbData, networkType: networkType)
            } else {
                return false
            }
        }
        return rustBackend.scanBlocks(dbCache: dbCache, dbData: dbData, networkType: Self.networkType)
    }
    
    static func createToAddress(
        dbData: URL,
        account: Int32,
        extsk: String,
        consensusBranchId: Int32,
        to address: String,
        value: Int64,
        memo: String?,
        spendParamsPath: String,
        outputParamsPath: String,
        networkType: NetworkType
    ) -> Int64 {
        -1
    }
    
    static func shouldSucceed(successRate: Float) -> Bool {
        let random = Float.random(in: 0.0...1.0)
        return random <= successRate
    }
    
    static func deriveExtendedFullViewingKey(_ spendingKey: String, networkType: NetworkType) throws -> String? {
        nil
    }
    
    static func deriveExtendedFullViewingKeys(seed: String, accounts: Int32, networkType: NetworkType) throws -> [String]? {
        nil
    }
    
    static func deriveExtendedSpendingKeys(seed: String, accounts: Int32, networkType: NetworkType) throws -> [String]? {
        nil
    }
    
    static func decryptAndStoreTransaction(dbData: URL, txBytes: [UInt8], minedHeight: Int32, networkType: NetworkType) -> Bool {
        false
    }
}
