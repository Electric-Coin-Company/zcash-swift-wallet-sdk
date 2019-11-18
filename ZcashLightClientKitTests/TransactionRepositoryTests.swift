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
        
        let id = "0BAFC5B83F5B39A5270144ECD98DBC65115055927EDDA8FF20F081FFF13E4780".hexDecodedData()
        
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
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllSentTransactions(limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all sent transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 0)
    }
    
    func testFindAllReceivedTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAllReceivedTransactions(limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all received transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 0)
    }
    
    func testFindAllTransactions() {
        var transactions: [ConfirmedTransactionEntity]?
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findAll(limit: Int.max) }())
        guard let txs = transactions else {
            XCTFail("find all transactions returned no transactions")
            return
        }
        
        XCTAssertEqual(txs.count, 27)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

extension String {
    /// A data representation of the hexadecimal bytes in this string.
    func hexDecodedData() -> Data {
        // Get the UTF8 characters of this string
        let chars = Array(utf8)
        
        // Keep the bytes in an UInt8 array and later convert it to Data
        var bytes = [UInt8]()
        bytes.reserveCapacity(count / 2)
        
        // It is a lot faster to use a lookup map instead of strtoul
        let map: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
            0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
            0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
        ]
        
        // Grab two characters at a time, map them and turn it into a byte
        for i in stride(from: 0, to: count, by: 2) {
            let index1 = Int(chars[i] & 0x1F ^ 0x10)
            let index2 = Int(chars[i + 1] & 0x1F ^ 0x10)
            bytes.append(map[index1] << 4 | map[index2])
        }
        
        return Data(bytes)
    }
}
