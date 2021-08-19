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

class AwfulLightWalletService: MockLightWalletService {
    override func latestBlockHeight() throws -> BlockHeight {
        throw LightWalletServiceError.criticalError
    }
    
    override func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        throw LightWalletServiceError.invalidBlock
    }
    
    override func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.invalidBlock))
        }
        
    }
    
    override func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.invalidBlock))
        }
    }
    
    override func submit(spendTransaction: Data, result: @escaping(Result<LightWalletServiceResponse,LightWalletServiceError>) -> Void) {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  result(.failure(LightWalletServiceError.invalidBlock))
              }
    }
       
       /**
       Submits a raw transaction over lightwalletd. Blocking
       */
       
    override func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        throw LightWalletServiceError.invalidBlock
    }
}

class SlightlyBadLightWalletService: MockLightWalletService {
   
    
    override func submit(spendTransaction: Data, result: @escaping(Result<LightWalletServiceResponse,LightWalletServiceError>) -> Void) {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.success(LightWalletServiceMockResponse.error))
              }
    }
       
       /**
       Submits a raw transaction over lightwalletd. Blocking
       */
       
    override func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        LightWalletServiceMockResponse.error
    }
}


extension LightWalletServiceMockResponse {
    static var error: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(errorCode: -100, errorMessage: "Ohhh this is bad dude, really bad, you lost all your internet money", unknownFields: UnknownStorage())
    }
    static var success: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())
    }
}

class MockRustBackend: ZcashRustBackendWelding {
    static func clearUtxos(dbData: URL, address: String, sinceHeight: BlockHeight, networkType: NetworkType) throws -> Int32 {
        -1
    }
    
    
    static func getNearestRewindHeight(dbData: URL, height: Int32, networkType: NetworkType) -> Int32 {
        -1
    }
    
    static func network(dbData: URL, address: String, sinceHeight: BlockHeight, networkType: NetworkType) throws -> Int32 {
        -1
    }
    
    static func initAccountsTable(dbData: URL, uvks: [UnifiedViewingKey], networkType: NetworkType) throws -> Bool {
        false
    }
    
    static func getVerifiedTransparentBalance(dbData: URL, address: String, networkType: NetworkType) throws -> Int64 {
        -1
    }
    
    static func getTransparentBalance(dbData: URL, address: String, networkType: NetworkType) throws -> Int64 {
        -1
    }
    
    static func putUnspentTransparentOutput(dbData: URL, address: String, txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight, networkType: NetworkType) throws -> Bool {
        false
    }
    
    static func downloadedUtxoBalance(dbData: URL, address: String, networkType: NetworkType) throws -> WalletBalance {
        throw RustWeldingError.genericError(message: "unimplemented")
    }
    
    static func createToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String, networkType: NetworkType) -> Int64 {
        -1
    }
    
    static func shieldFunds(dbCache: URL, dbData: URL, account: Int32, tsk: String, extsk: String, memo: String?, spendParamsPath: String, outputParamsPath: String, networkType: NetworkType) -> Int64 {
        -1
    }
    
    static func deriveTransparentAddressFromSeed(seed: [UInt8], account: Int, index: Int, networkType: NetworkType) throws -> String? {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func deriveTransparentPrivateKeyFromSeed(seed: [UInt8], account: Int, index: Int, networkType: NetworkType) throws -> String? {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func deriveTransparentAddressFromSecretKey(_ tsk: String, networkType: NetworkType) throws -> String? {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func derivedTransparentAddressFromPublicKey(_ pubkey: String, networkType: NetworkType) throws -> String {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func deriveUnifiedViewingKeyFromSeed(_ seed: [UInt8], numberOfAccounts: Int, networkType: NetworkType) throws -> [UnifiedViewingKey] {
        throw KeyDerivationErrors.unableToDerive
    }
    
    static func isValidExtendedFullViewingKey(_ key: String, networkType: NetworkType) throws -> Bool {
        false
    }
    
    static func deriveTransparentPrivateKeyFromSeed(seed: [UInt8], networkType: NetworkType) throws -> String? {
        nil
    }
    
    static func initAccountsTable(dbData: URL, exfvks: [String], networkType: NetworkType) throws -> Bool {
        false
    }
    
    static func deriveTransparentAddressFromSeed(seed: [UInt8], networkType: NetworkType) throws -> String? {
        nil
    }
    
    static func deriveExtendedFullViewingKeys(seed: [UInt8], accounts: Int32, networkType: NetworkType) throws -> [String]? {
        nil
    }
    
    static func deriveExtendedSpendingKeys(seed: [UInt8], accounts: Int32, networkType: NetworkType) throws -> [String]? {
        nil
    }
    
    static func deriveShieldedAddressFromSeed(seed: [UInt8], accountIndex: Int32, networkType: NetworkType) throws -> String? {
        nil
    }
    
    static func deriveShieldedAddressFromViewingKey(_ extfvk: String, networkType: NetworkType) throws -> String? {
        nil
    }
    
    
    static func consensusBranchIdFor(height: Int32, networkType: NetworkType) throws -> Int32 {
        guard let c = consensusBranchID else {
            return try rustBackend.consensusBranchIdFor(height: height, networkType: networkType)
        }
        return c
    }
    
    static var networkType = NetworkType.testnet
    static var mockDataDb = false
    static var mockAcounts = false
    static var mockError: RustWeldingError?
    static var mockLastError: String?
    static var mockAccounts: [String]?
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
    
    static func isValidShieldedAddress(_ address: String, networkType: NetworkType) throws -> Bool {
        true
    }
    
    static func isValidTransparentAddress(_ address: String, networkType: NetworkType) throws -> Bool {
        true
    }
    
    static func initDataDb(dbData: URL, networkType: NetworkType) throws {
        if !mockDataDb {
            try rustBackend.initDataDb(dbData: dbData, networkType: networkType)
        }
    }
    
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32, networkType: NetworkType) -> [String]? {
        mockAccounts ?? rustBackend.initAccountsTable(dbData: dbData, seed: seed, accounts: accounts, networkType: networkType)
    }
    
    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String, networkType: NetworkType) throws {
        if !mockDataDb {
            try rustBackend.initBlocksTable(dbData: dbData, height: height, hash: hash, time: time, saplingTree: saplingTree, networkType: networkType)
        }
    }
    
    static func getAddress(dbData: URL, account: Int32, networkType: NetworkType) -> String? {
        mockAddresses?[Int(account)] ?? rustBackend.getAddress(dbData: dbData, account: account, networkType: networkType)
    }
    
    static func getBalance(dbData: URL, account: Int32, networkType: NetworkType) -> Int64 {
        mockBalance ?? rustBackend.getBalance(dbData: dbData, account: account, networkType: networkType)
    }
    
    static func getVerifiedBalance(dbData: URL, account: Int32, networkType: NetworkType) -> Int64 {
        mockVerifiedBalance ?? rustBackend.getVerifiedBalance(dbData: dbData, account: account, networkType: networkType)
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
    
    private static func validationResult(dbCache: URL, dbData: URL, networkType: NetworkType) -> Int32{
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
    
     static func createToAddress(dbData: URL, account: Int32, extsk: String, consensusBranchId: Int32, to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String, networkType: NetworkType) -> Int64 {
//        mockCreateToAddress ?? rustBackend.createToAddress(dbData: dbData, account: account, extsk: extsk, consensusBranchId: consensusBranchId, to: to, value: value, memo: memo, spendParamsPath: spendParamsPath, outputParamsPath: outputParamsPath)
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
    
    static func decryptAndStoreTransaction(dbData: URL, tx: [UInt8], networkType: NetworkType) -> Bool {
        false
    }
    
}
