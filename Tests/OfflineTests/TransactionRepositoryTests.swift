//
//  TransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/16/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping
class TransactionRepositoryTests: XCTestCase {
    var transactionRepository: TransactionRepository!
    
    override func setUp() {
        super.setUp()

        transactionRepository = try! TestDbBuilder.transactionRepository()
    }
    
    override func tearDown() {
        super.tearDown()
        transactionRepository = nil
    }
    
    func testCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countAll() }())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 21)
    }
    
    func testCountUnmined() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countUnmined() }())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 0)
    }
    
    func testFindById() {
        var transaction: TransactionNG.Overview!
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.find(id: 10) }())

        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 663942)
        XCTAssertEqual(transaction.index, 5)
    }
    
    func testFindByTxId() {
        var transaction: TransactionNG.Overview!

        let id = Data(fromHexEncodedString: "01af48bcc4e9667849a073b8b5c539a0fc19de71aac775377929dc6567a36eff")!
        
        XCTAssertNoThrow(
            try { transaction = try self.transactionRepository.find(rawID: id) }()
        )

        XCTAssertEqual(transaction.id, 8)
        XCTAssertEqual(transaction.minedHeight, 663922)
        XCTAssertEqual(transaction.index, 1)
    }
    
    func testFindAllSentTransactions() {
        var transactions: [TransactionNG.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .sent) }())
        XCTAssertEqual(transactions.count, 13)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, true) }
    }
    
    func testFindAllReceivedTransactions() {
        var transactions: [TransactionNG.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .received) }())
        XCTAssertEqual(transactions.count, 8)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, false) }
    }
    
    func testFindAllTransactions() {
        var transactions: [TransactionNG.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all) }())
        XCTAssertEqual(transactions.count, 21)
    }
    
    func testFindAllPerformance() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            do {
                _ = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
            } catch {
                XCTFail("find all failed")
            }
        }
    }
    
    func testFindAllFrom() throws {
        var transaction: TransactionNG.Overview!
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.find(id: 16) }())

        var transactionsFrom: [TransactionNG.Overview] = []
        XCTAssertNoThrow(try { transactionsFrom = try self.transactionRepository.find(from: transaction, limit: Int.max, kind: .all) }())

        XCTAssertEqual(transactionsFrom.count, 8)

        transactionsFrom.forEach { preceededTransaction in
            XCTAssertLessThan(preceededTransaction.index, transaction.index)
            XCTAssertLessThan(preceededTransaction.blocktime, transaction.blocktime)
        }
    }
}

extension Data {
    init?(fromHexEncodedString string: String) {
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(bytes: UInt16) -> UInt8? {
            switch bytes {
            case 0x30 ... 0x39:
                return UInt8(bytes - 0x30)
            case 0x41 ... 0x46:
                return UInt8(bytes - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(bytes - 0x61 + 10)
            default:
                return nil
            }
        }

        self.init(capacity: string.utf16.count / 2)
        var even = true
        var byte: UInt8 = 0
        for char in string.utf16 {
            guard let val = decodeNibble(bytes: char) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even.toggle()
        }
        guard even else { return nil }
    }
}
