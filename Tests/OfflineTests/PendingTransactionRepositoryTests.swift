//
//  PendingTransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/27/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable force_try force_unwrapping implicitly_unwrapped_optional
class PendingTransactionRepositoryTests: XCTestCase {
    let dbUrl = try! TestDbBuilder.pendingTransactionsDbURL()
    let recipient = SaplingAddress(validatedEncoding: "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6")

    var pendingRepository: PendingTransactionRepository!

    override func setUp() {
        super.setUp()
        cleanUpDb()
        let pendingDbProvider = SimpleConnectionProvider(path: try! TestDbBuilder.pendingTransactionsDbURL().absoluteString)
        let migrations = try! MigrationManager(cacheDbConnection: InMemoryDbProvider(), pendingDbConnection: pendingDbProvider, networkType: .testnet)
        try! migrations.performMigration()
        pendingRepository = PendingTransactionSQLDAO(dbProvider: pendingDbProvider)
    }
    
    override func tearDown() {
        super.tearDown()
        cleanUpDb()
    }
    
    func cleanUpDb() {
        try? FileManager.default.removeItem(at: TestDbBuilder.pendingTransactionsDbURL())
    }
    
    func testCreate() {
        let transaction = createAndStoreMockedTransaction()
        
        guard let id = transaction.id, id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        var expectedTx: PendingTransactionEntity?
        XCTAssertNoThrow(try { expectedTx = try pendingRepository.find(by: id) }())
        
        guard let expected = expectedTx else {
            XCTFail("failed to retrieve mocked transaction by id \(id) that was just inserted")
            return
        }
        
        XCTAssertEqual(transaction.accountIndex, expected.accountIndex)
        XCTAssertEqual(transaction.value, expected.value)
        XCTAssertEqual(transaction.recipient, expected.recipient)
    }
    
    func testFindById() {
        let transaction = createAndStoreMockedTransaction()
        
        var expected: PendingTransactionEntity?
        
        guard let id = transaction.id else {
            XCTFail("transaction with no id")
            return
        }

        XCTAssertNoThrow(try { expected = try pendingRepository.find(by: id) }())
        XCTAssertNotNil(expected)
    }
    
    func testCancel() {
        let transaction = createAndStoreMockedTransaction()

        guard let id = transaction.id else {
            XCTFail("transaction with no id")
            return
        }

        guard id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        XCTAssertNoThrow(try pendingRepository.cancel(transaction))
    }
    
    func testDelete() {
        let transaction = createAndStoreMockedTransaction()

        guard let id = transaction.id else {
            XCTFail("transaction with no id")
            return
        }

        guard id >= 0 else {
            XCTFail("failed to create mocked transaction that was just inserted")
            return
        }
        
        XCTAssertNoThrow(try pendingRepository.delete(transaction))
        
        var unexpectedTx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { unexpectedTx = try pendingRepository.find(by: id) }())
        XCTAssertNil(unexpectedTx)
    }
    
    func testGetAll() {
        var mockTransactions: [PendingTransactionEntity] = []
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
        let transaction = createAndStoreMockedTransaction()

        guard let id = transaction.id else {
            XCTFail("transaction with no id")
            return
        }

        var stored: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { stored = try pendingRepository.find(by: id) }())
        
        guard stored != nil else {
            XCTFail("failed to store tx")
            return
        }

        let oldEncodeAttempts = stored!.encodeAttempts
        let oldSubmitAttempts = stored!.submitAttempts
        
        stored!.encodeAttempts += 1
        stored!.submitAttempts += 5
        
        XCTAssertNoThrow(try pendingRepository.update(stored!))
        
        guard let updatedTransaction = try? pendingRepository.find(by: stored!.id!) else {
            XCTFail("failed to retrieve updated transaction with id: \(stored!.id!)")
            return
        }
        
        XCTAssertEqual(updatedTransaction.encodeAttempts, oldEncodeAttempts + 1)
        XCTAssertEqual(updatedTransaction.submitAttempts, oldSubmitAttempts + 5)
        XCTAssertEqual(updatedTransaction.recipient, stored!.recipient)
    }
    
    func createAndStoreMockedTransaction(with value: Zatoshi = Zatoshi(1000)) -> PendingTransactionEntity {
        var transaction = mockTransaction(with: value)
        var id: Int?
        
        XCTAssertNoThrow(try { id = try pendingRepository.create(transaction) }())
        transaction.id = Int(id ?? -1)
        return transaction
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            _ = try! pendingRepository.getAll()
        }
    }
    
    private func mockTransaction(with value: Zatoshi = Zatoshi(1000)) -> PendingTransactionEntity {
        PendingTransaction(value: value, recipient: .address(.sapling(recipient)), memo: .empty(), account: 0)
    }
}
