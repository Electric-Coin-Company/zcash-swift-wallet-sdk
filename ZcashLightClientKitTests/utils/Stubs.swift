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
    static func initAccountsTable(dbData: URL, exfvks: [String]) throws -> Bool {
        false
    }
    
    static func deriveTransparentAddressFromSeed(seed: [UInt8]) throws -> String? {
        nil
    }
    
    static func deriveExtendedFullViewingKeys(seed: [UInt8], accounts: Int32) throws -> [String]? {
        nil
    }
    
    static func deriveExtendedSpendingKeys(seed: [UInt8], accounts: Int32) throws -> [String]? {
        nil
    }
    
    static func deriveShieldedAddressFromSeed(seed: [UInt8], accountIndex: Int32) throws -> String? {
        nil
    }
    
    static func deriveShieldedAddressFromViewingKey(_ extfvk: String) throws -> String? {
        nil
    }
    
    
    static func consensusBranchIdFor(height: Int32) throws -> Int32 {
        -1
    }
    
    
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
    
    
    static func lastError() -> RustWeldingError? {
        mockError ?? rustBackend.lastError()
    }
    
    static func getLastError() -> String? {
        mockLastError ?? rustBackend.getLastError()
    }
    
    static func isValidShieldedAddress(_ address: String) throws -> Bool {
        true
    }
    
    static func isValidTransparentAddress(_ address: String) throws -> Bool {
        true
    }
    
    static func initDataDb(dbData: URL) throws {
        if !mockDataDb {
            try rustBackend.initDataDb(dbData: dbData)
        }
    }
    
    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]? {
        mockAccounts ?? rustBackend.initAccountsTable(dbData: dbData, seed: seed, accounts: accounts)
    }
    
    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String) throws {
        if !mockDataDb {
            try rustBackend.initBlocksTable(dbData: dbData, height: height, hash: hash, time: time, saplingTree: saplingTree)
        }
    }
    
    static func getAddress(dbData: URL, account: Int32) -> String? {
        mockAddresses?[Int(account)] ?? rustBackend.getAddress(dbData: dbData, account: account)
    }
    
    static func getBalance(dbData: URL, account: Int32) -> Int64 {
        mockBalance ?? rustBackend.getBalance(dbData: dbData, account: account)
    }
    
    static func getVerifiedBalance(dbData: URL, account: Int32) -> Int64 {
        mockVerifiedBalance ?? rustBackend.getVerifiedBalance(dbData: dbData, account: account)
    }
    
    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        mockMemo ?? rustBackend.getReceivedMemoAsUTF8(dbData: dbData, idNote: idNote)
    }
    
    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        mockSentMemo ?? getSentMemoAsUTF8(dbData: dbData, idNote: idNote)
    }
    
    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32 {
        if let rate = self.mockValidateCombinedChainSuccessRate {
            if shouldSucceed(successRate: rate) {
                return validationResult(dbCache: dbCache, dbData: dbData)
            } else {
                return Int32(mockValidateCombinedChainFailureHeight)
            }
        } else if let attempts = self.mockValidateCombinedChainFailAfterAttempts {
            self.mockValidateCombinedChainFailAfterAttempts = attempts - 1
            if attempts > 0 {
                return validationResult(dbCache: dbCache, dbData: dbData)
            } else {
                
                if attempts == 0 {
                    return Int32(mockValidateCombinedChainFailureHeight)
                } else if attempts < 0 && mockValidateCombinedChainKeepFailing {
                    return Int32(mockValidateCombinedChainFailureHeight)
                } else {
                    return validationResult(dbCache: dbCache, dbData: dbData)
                }
            }
        }
        return rustBackend.validateCombinedChain(dbCache: dbCache, dbData: dbData)
    }
    
    private static func validationResult(dbCache: URL, dbData: URL) -> Int32{
        if mockDataDb {
            return -1
        } else {
            return rustBackend.validateCombinedChain(dbCache: dbCache, dbData: dbData)
        }
    }
    
    static func rewindToHeight(dbData: URL, height: Int32) -> Bool {
        mockDataDb ? true : rustBackend.rewindToHeight(dbData: dbData, height: height)
    }
    
    static func scanBlocks(dbCache: URL, dbData: URL) -> Bool {
        if let rate = mockScanblocksSuccessRate {
            
            if shouldSucceed(successRate: rate) {
                return mockDataDb ? true : rustBackend.scanBlocks(dbCache: dbCache, dbData: dbData)
            } else {
                return false
            }
        }
        return rustBackend.scanBlocks(dbCache: dbCache, dbData: dbData)
    }
    
     static func createToAddress(dbData: URL, account: Int32, extsk: String, consensusBranchId: Int32, to: String, value: Int64, memo: String?, spendParamsPath: String, outputParamsPath: String) -> Int64 {
        mockCreateToAddress ?? rustBackend.createToAddress(dbData: dbData, account: account, extsk: extsk, consensusBranchId: consensusBranchId, to: to, value: value, memo: memo, spendParamsPath: spendParamsPath, outputParamsPath: outputParamsPath)
    }
    
    static func shouldSucceed(successRate: Float) -> Bool {
        let random = Float.random(in: 0.0...1.0)
        return random <= successRate
    }
    
    static func deriveExtendedFullViewingKey(_ spendingKey: String) throws -> String? {
        nil
    }
    
    static func deriveExtendedFullViewingKeys(seed: String, accounts: Int32) throws -> [String]? {
        nil
    }
    
    static func deriveExtendedSpendingKeys(seed: String, accounts: Int32) throws -> [String]? {
        nil
    }
    
    static func decryptAndStoreTransaction(dbData: URL, tx: [UInt8]) -> Bool {
        false
    }
    
}
