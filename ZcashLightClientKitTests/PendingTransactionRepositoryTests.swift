//
//  PendingTransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/27/19.
//

import XCTest
@testable import ZcashLightClientKit
class PendingTransactionRepositoryTests: XCTestCase {
    
    var pendingRepository: PendingTransactionRepository!
    
    let dbUrl = try! TestDbBuilder.pendingTransactionsDbURL()
    
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    override func setUp() {
        cleanUpDb()
        let dao = PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: try! TestDbBuilder.pendingTransactionsDbURL().absoluteString))
        try! dao.createrTableIfNeeded()
        pendingRepository = dao
        
    }
    
    override func tearDown() {
        cleanUpDb()
    }
    
    func cleanUpDb() {
        try? FileManager.default.removeItem(at: TestDbBuilder.pendingTransactionsDbURL())
    }
    
    func testCreate() {
        
        let tx = createAndStoreMockedTransaction()
        
        guard let id = tx.id, id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        var expectedTx: PendingTransactionEntity?
        XCTAssertNoThrow(try { expectedTx = try pendingRepository.find(by: id)}())
        
        guard let expected = expectedTx else {
            XCTFail("failed to retrieve mocked transaction by id \(id) that was just inserted")
            return
        }
        
        XCTAssertEqual(tx.accountIndex, expected.accountIndex)
        XCTAssertEqual(tx.value, expected.value)
        XCTAssertEqual(tx.toAddress, expected.toAddress)
    }
    
    func testFindById() {
        let tx = createAndStoreMockedTransaction()
        
        var expected: PendingTransactionEntity?
        
        guard let id = tx.id else {
            XCTFail("transaction with no id")
            return
        }
        XCTAssertNoThrow(try { expected = try pendingRepository.find(by: id)}())
        
        XCTAssertNotNil(expected)
    }
    
    func testCancel() {
        let tx = createAndStoreMockedTransaction()
        guard let id = tx.id else {
                  XCTFail("transaction with no id")
                  return
              }
        guard id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        XCTAssertNoThrow(try pendingRepository.cancel(tx))
    }
    
    func testDelete() {
        let tx = createAndStoreMockedTransaction()
        guard let id = tx.id else {
                  XCTFail("transaction with no id")
                  return
              }
        guard id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        XCTAssertNoThrow(try pendingRepository.delete(tx))
        
        var unexpectedTx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { unexpectedTx = try pendingRepository.find(by: id) }())
        
        XCTAssertNil(unexpectedTx)
    }
    
    func testGetAll() {
        var mockTransactions = [PendingTransactionEntity]()
        for _ in 1...100 {
            mockTransactions.append(createAndStoreMockedTransaction())
        }
        
        var all: [PendingTransactionEntity]?
        
        XCTAssertNoThrow(try { all = try pendingRepository.getAll() }())
        
        guard let allTxs = all else {
            XCTFail("failed to get all transactions")
            return
        }
        
        XCTAssertEqual(mockTransactions.count, allTxs.count)
        
    }
    
    func testUpdate() {
        let newAccountIndex = 1
        let newValue: Int = 123_456
        let tx = createAndStoreMockedTransaction()
        guard let id = tx.id else {
                  XCTFail("transaction with no id")
                  return
              }
        var stored: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { stored = try pendingRepository.find(by: id)}())
        
        guard stored != nil else {
            XCTFail("failed to store tx")
            return
        }
        
        stored!.accountIndex = newAccountIndex
        stored!.value = newValue
        
        XCTAssertNoThrow(try pendingRepository.update(stored!))
        
        guard let updatedTransaction = try? pendingRepository.find(by: stored!.id!) else {
            XCTFail("failed to retrieve updated transaction with id: \(stored!.id!)")
            return
        }
        
        XCTAssertEqual(updatedTransaction.value, newValue)
        XCTAssertEqual(updatedTransaction.accountIndex, newAccountIndex)
        XCTAssertEqual(updatedTransaction.toAddress, stored!.toAddress)
    }
    
    func createAndStoreMockedTransaction() -> PendingTransactionEntity {
        var tx = mockTransaction()
        var id: Int?
        
        XCTAssertNoThrow(try { id = try pendingRepository.create(tx) }())
        tx.id = Int(id ?? -1)
        return tx
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            _ = try! pendingRepository.getAll()
        }
    }
    
    private func mockTransaction() -> PendingTransactionEntity {
        PendingTransaction(value: Int.random(in: 1 ... 1_000_000), toAddress: recipientAddress, memo: nil, account: 0)
    }
    
}
