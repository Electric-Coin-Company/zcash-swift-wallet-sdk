//
//  ZcashRustBackendWelding.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

protocol ZcashRustBackendWelding {

    static func getLastError() -> String?

    static func initDataDb(dbData: URL) -> Bool

    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]?
    
    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String) -> Bool

    static func getAddress(dbData: URL, account: Int32) -> String?

    static func getBalance(dbData: URL, account: Int32) -> Int64

    static func getVerifiedBalance(dbData: URL, account: Int32) -> Int64

    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64) -> String?

    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64) -> String?

    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32

    static func rewindToHeight(dbData: URL, height: Int32) -> Bool

    static func scanBlocks(dbCache: URL, dbData: URL) -> Bool

    static func sendToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParams: URL, outputParams: URL) -> Int64

}
