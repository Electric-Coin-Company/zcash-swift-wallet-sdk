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
        XCTFail("not implemented")
    }

    func testFindById() {
        XCTFail("not implemented")
    }
    
    func testFindByTxId() {
        XCTFail("not implemented")
    }
    
    func testFindAllSentTransactions() {
        XCTFail("not implemented")
    }
    
    func testFindAllReceivedTransactions() {
        XCTFail("not implemented")
    }
    
    func testFindAllTransactions() {
        XCTFail("not implemented")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
