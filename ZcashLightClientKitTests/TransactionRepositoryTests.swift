//
//  TransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/16/19.
//

import XCTest
@testable import ZcashLightClientKit
class TransactionRepositoryTests: XCTestCase {
    
    var transactionRepository: TransactionRepository!
    
    override func setUp() {
        transactionRepository = TestDbBuilder.transactionRepository()
    }
    
    override func tearDown() {
        transactionRepository = nil
    }
    
    func testCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countAll()}())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 27)
        
    }
    
    func testCountUnmined() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countUnmined()}())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 0)
    }
    
    func testFindById() {
        var tx: TransactionEntity?
        XCTAssertNoThrow(try { tx = try self.transactionRepository.findBy(id: 10)}())
        guard let transaction = tx else {
            XCTFail("transaction is nil")
            return
        }
        
        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 652812)
        XCTAssertEqual(transaction.transactionIndex, 5)
        
    }
    
    func testFindByTxId() {
        var tx: TransactionEntity?
        
        let id = Data(fromHexEncodedString: "0BAFC5B83F5B39A5270144ECD98DBC65115055927EDDA8FF20F081FFF13E4780")!
        
        XCTAssertNoThrow(try { tx = try self.transactionRepository.findBy(rawId: id)}())
        guard let transaction = tx else {
            XCTFail("transaction is nil")
            return
        }
        
        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 652812)
        XCTAssertEqual(transaction.transactionIndex, 5)
    }
    
    func testFindAllSentTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllSentTransactions(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all sent transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 0)
    }
    
    func testFindAllReceivedTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllReceivedTransactions(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all received transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 27)
    }
    
    func testFindAllTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 27)
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
        guard let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
              let allFromNil = try self.transactionRepository.findAll(from: nil, limit: Int.max)
        else {
            return XCTFail("find all failed")
        }
        
        XCTAssertEqual(transactions.count, allFromNil.count)
        
        for t in transactions {
            guard allFromNil.first(where: { $0.rawTransactionId == t.rawTransactionId}) != nil else {
                XCTFail("not equal")
                return
            }
        }
    }
    
    func testFindAllFromSlice() throws {
        
        let limit = 4
        let start = 7
        guard let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
              let allFromNil = try self.transactionRepository.findAll(from: transactions[start], limit: limit)
        else {
            return XCTFail("find all failed")
        }
        
        XCTAssertEqual(limit, allFromNil.count)
        
        let slice = transactions[start + 1 ... start + limit]
        XCTAssertEqual(slice.count, allFromNil.count)
        for t in slice {
            guard allFromNil.first(where: { $0.rawTransactionId == t.rawTransactionId}) != nil else {
                XCTFail("not equal")
                return
            }
        }
    }
    
    
    func testFindAllFromLastSlice() throws {
        
        let limit = 10
        let start = 20
        guard let transactions = try self.transactionRepository.findAll(offset: 0, limit: Int.max),
              let allFromNil = try self.transactionRepository.findAll(from: transactions[start], limit: limit)
        else {
            return XCTFail("find all failed")
        }
        
        let slice = transactions[start + 1 ..< transactions.count]
        XCTAssertEqual(slice.count, allFromNil.count)
        for t in slice {
            guard allFromNil.first(where: { $0.rawTransactionId == t.rawTransactionId}) != nil else {
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
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }

        self.init(capacity: string.utf16.count/2)
        var even = true
        var byte: UInt8 = 0
        for c in string.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
}
