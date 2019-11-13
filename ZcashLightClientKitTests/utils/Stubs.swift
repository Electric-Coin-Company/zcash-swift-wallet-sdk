//
//  Stubs.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
@testable import ZcashLightClientKit

class AwfulLightWalletService: LightWalletService {
    func latestBlockHeight() throws -> BlockHeight {
        throw LightWalletServiceError.generalError
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        throw LightWalletServiceError.invalidBlock
    }
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.generalError))
        }
        
    }
    
    func blockRange(_ range: Range<BlockHeight>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.generalError))
        }
    }
    
}

class MockRustBackend: ZcashRustBackendWelding {
    static var mockDataDb = true
    static var mockAcounts = true
    static var mockError: RustWeldingError?
    static var mockLastError: String?
    static var mockAccounts: [String]?
    static var mockAddresses: [String]?
    static var mockBalance: Int64?
    static var mockVerifiedBalance: Int64?
    static var mockMemo: String?
    static var mockSentMemo: String?
    static var mockValidateCombinedChainSuccessRate: Float?
    static var mockScanblocksSuccessRate: Float?
    static var mockSendToAddress: Int64?
    static var rustBackend = ZcashRustBackend.self
    
    static func lastError() -> RustWeldingError? {
        mockError ?? rustBackend.lastError()
    }
    
    static func getLastError() -> String? {
        mockLastError ?? rustBackend.getLastError()
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
                       if mockDataDb {
                           return -1
                       }
                       return rustBackend.validateCombinedChain(dbCache: dbCache, dbData: dbData)
            } else {
                return 0
            }
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
    
    static func sendToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParams: URL, outputParams: URL) -> Int64 {
        mockSendToAddress ?? rustBackend.sendToAddress(dbData: dbData, account: account, extsk: extsk, to: to, value: value, memo: memo, spendParams: spendParams, outputParams: outputParams)
    }
    
    static func shouldSucceed(successRate: Float) -> Bool {
        let random = Float.random(in: 0.0...1.0)
        return random <= successRate
    }
    
}
