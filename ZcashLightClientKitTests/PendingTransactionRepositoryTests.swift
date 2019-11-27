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
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let dao =  PendingTransactionSQLDAO(dbProvider: SimpleConnectionProvider(path: try! TestDbBuilder.pendingTransactionsDbURL().absoluteString))
        try! dao.createrTableIfNeeded()
        pendingRepository = dao
        
    }

    override func tearDown() {
        XCTFail()
    }

    func testCreate() {
       XCTFail()
    }
    
    func testCancel() {
           XCTFail()
    }

    func testDelete() {
        XCTFail()
    }
    
    func testGetAll() {
        XCTFail()
    }
    
    func testFindById() {
        XCTFail()
    }
    
    func testUpdate() {
        XCTFail()
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            _ = try! pendingRepository.getAll()
        }
    }

}
