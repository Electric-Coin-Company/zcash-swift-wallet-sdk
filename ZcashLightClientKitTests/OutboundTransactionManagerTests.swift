//
//  OutboundTransactionManagerTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/26/19.
//

import XCTest
@testable import ZcashLightClientKit
class OutboundTransactionManagerTests: XCTestCase {
    
    var transactionManager: OutboundTransactionManager!
    
    var transactionRepository: PendingTransactionRepository!
    
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)
    var cacheDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedCacheDbURL()!)
    var initializer: Initializer!
    let spendingKey = "secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4kwlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcq9rc0qn"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    let zpend: Int64 = 500_000
    
    
    override func setUp() {
        
        try! dataDbHandle.setUp()
        try! cacheDbHandle.setUp()
        
    }
    
    override func tearDown() {
        transactionManager = nil
        dataDbHandle.dispose()
        cacheDbHandle.dispose()
    }
    
    func testInitSpend() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        XCTAssertEqual(pendingTx.toAddress, recipientAddress)
        XCTAssertEqual(pendingTx.memo, nil)
        XCTAssertEqual(pendingTx.value, zpend)
        
    }
    
    func testEncodeSpend() {
        let expect = XCTestExpectation(description: self.description)
        
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        transactionManager.encode(spendingKey: spendingKey, pendingTransaction: pendingTx) { (result) in
            expect.fulfill()
            
            switch result {
            case .failure(let error):
                XCTFail("failed with error: \(error)")
            case .success(let tx):
                XCTAssertEqual(tx.id, pendingTx.id)
            }
        }
        
    }
    
    
    func testSubmit() {
        
        let encodeExpect = XCTestExpectation(description: "encode")
        
        let submitExpect = XCTestExpectation(description: "submit")
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        var encodedTx: PendingTransactionEntity?
        transactionManager.encode(spendingKey: spendingKey, pendingTransaction: pendingTx) { (result) in
            encodeExpect.fulfill()
            
            switch result {
            case .failure(let error):
                XCTFail("failed with error: \(error)")
            case .success(let tx):
                XCTAssertEqual(tx.id, pendingTx.id)
                encodedTx = tx
            }
        }
        wait(for: [encodeExpect], timeout: 60)
        
        guard let submittableTx = encodedTx else {
            XCTFail("failed to encode tx")
            return
        }
        
        
        transactionManager.submit(pendingTransaction: submittableTx) { (result) in
            submitExpect.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("submission failed with error: \(error)")
            case .success(let successfulTx):
                XCTAssertEqual(submittableTx.id, successfulTx.id)
            }
            
        }
        wait(for: [submitExpect], timeout: 5)
    }
    
    
    func testApplyMinedHeight() {
        var tx: PendingTransactionEntity?
        
        let minedHeight = 789_000
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        let minedTransaction = transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)
        
        XCTAssertTrue(minedTransaction.isMined)
        XCTAssertEqual(minedTransaction.minedHeight, minedHeight)
        
    }
    
    func testCancel() {
        
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        let cancellationResult = transactionManager.cancel(pendingTransaction: pendingTx)
        
        guard let retrievedTransaction = try! transactionRepository.find(by: pendingTx.id) else {
            XCTFail("failed to retrieve previously created transation")
            return
        }
        
        XCTAssertEqual(cancellationResult, retrievedTransaction.isCancelled)
        
    }
    
    
    func testAllPendingTransactions() {
        
        let txCount = 100
        for i in 0 ..< txCount {
            var tx: PendingTransactionEntity?
            
            XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
            guard tx != nil else {
                XCTFail("failed to create pending transaction \(i)")
                return
            }
            
        }
        
        guard let allPending = try! transactionManager.allPendingTransactions() else {
            XCTFail("failed to retrieve all pending transactions")
            return
        }
        
        XCTAssertEqual(allPending.count, txCount)
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
