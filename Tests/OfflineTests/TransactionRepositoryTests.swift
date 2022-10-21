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
        var transaction: TransactionEntity?
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.findBy(id: 10) }())
        guard let transaction = transaction else {
            XCTFail("transaction is nil")
            return
        }
        
        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 663942)
        XCTAssertEqual(transaction.transactionIndex, 5)
    }
    
    func testFindByTxId() {
        var transaction: TransactionEntity?

        let id = Data(fromHexEncodedString: "01af48bcc4e9667849a073b8b5c539a0fc19de71aac775377929dc6567a36eff")!
        
        XCTAssertNoThrow(
            try { transaction = try self.transactionRepository.findBy(rawId: id) }()
        )

        guard let transaction = transaction else {
            XCTFail("transaction is nil")
            return
        }
        
        XCTAssertEqual(transaction.id, 8)
        XCTAssertEqual(transaction.minedHeight, 663922)
        XCTAssertEqual(transaction.transactionIndex, 1)
    }
    
    func testFindAllSentTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllSentTransactions(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all sent transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 13)
    }
    
    func testFindAllReceivedTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllReceivedTransactions(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all received transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 7)
    }
    
    func testFindAllTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 20)
    }
    
    func testFindAllPerformance() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            
            do {
                _ = try self.transactionRepository.findAll(offset: 0, limit: Int.max)
            } catch {
                XCTFail("find all failed")
            }
        }
    }
    
    func testFindAllFrom() throws {
        guard
            let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
            let allFromNil = try self.transactionRepository.findAll(from: nil, limit: Int.max)
        else {
            return XCTFail("find all failed")
        }
        
        XCTAssertEqual(transactions.count, allFromNil.count)
        
        for transaction in transactions {
            guard allFromNil.first(where: { $0.rawTransactionId == transaction.rawTransactionId }) != nil else {
                XCTFail("not equal")
                return
            }
        }
    }
    
    func testFindAllFromSlice() throws {
        let limit = 4
        let start = 7
        guard
            let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
            let allFromNil = try self.transactionRepository.findAll(from: transactions[start], limit: limit)
        else {
            return XCTFail("find all failed")
        }
        
        XCTAssertEqual(limit, allFromNil.count)
        
        let slice = transactions[start + 1 ... start + limit]
        XCTAssertEqual(slice.count, allFromNil.count)
        for transaction in slice {
            guard allFromNil.first(where: { $0.rawTransactionId == transaction.rawTransactionId }) != nil else {
                XCTFail("not equal")
                return
            }
        }
    }
    
    func testFindAllFromLastSlice() throws {
        let limit = 5
        let start = 15
        guard
            let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
            let allFromNil = try self.transactionRepository.findAll(from: transactions[start], limit: limit)
        else {
            return XCTFail("find all failed")
        }

        let slice = transactions[start + 1 ..< transactions.count]
        XCTAssertEqual(slice.count, allFromNil.count)
        for transaction in slice {
            guard allFromNil.first(where: { $0.rawTransactionId == transaction.rawTransactionId }) != nil else {
                XCTFail("not equal")
                return
            }
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
