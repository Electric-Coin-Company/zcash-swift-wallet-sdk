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
    var encoder: TransactionEncoder!
    var pendingRespository: PendingTransactionSQLDAO!
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)
    var cacheDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedCacheDbURL()!)
    var pendingDbhandle = TestDbHandle(originalDb: try! TestDbBuilder.pendingTransactionsDbURL())
    var service: LightWalletService!
    var initializer: Initializer!
    let spendingKey = "secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4kwlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcq9rc0qn"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    let zpend: Int = 500_000
    
    override func setUp() {
        
        try! dataDbHandle.setUp()
        try! cacheDbHandle.setUp()
        pendingRespository = PendingTransactionSQLDAO(dbProvider: pendingDbhandle.connectionProvider(readwrite: true))
        
        try! pendingRespository.createrTableIfNeeded()
        
        initializer = Initializer(cacheDbURL: cacheDbHandle.readWriteDb,
                                  dataDbURL: dataDbHandle.readWriteDb,
                                  pendingDbURL: try! TestDbBuilder.pendingTransactionsDbURL(),
                                  endpoint: LightWalletEndpointBuilder.default,
                                  spendParamsURL: try! __spendParamsURL(),
                                  outputParamsURL: try! __outputParamsURL())
        
        encoder = WalletTransactionEncoder(initializer: initializer)
        transactionManager = PersistentTransactionManager(encoder: encoder, service: MockLightWalletService(latestBlockHeight: 620999), repository: pendingRespository)
        
        
    }
    
    override func tearDown() {
        transactionManager = nil
        encoder = nil
        service = nil
        initializer = nil
        pendingRespository = nil 
        dataDbHandle.dispose()
        cacheDbHandle.dispose()
        pendingDbhandle.dispose()
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
    
    func testEncodeSpendSucess() {
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
                XCTAssertTrue(tx.encodeAttempts > 0)
                XCTAssertFalse(tx.isFailedEncoding)
            }
        }
        wait(for: [expect], timeout: 20)
        
    }
    
    func testSubmitFailed() {
        transactionManager = PersistentTransactionManager(encoder: encoder, service: SlightlyBadLightWalletService(latestBlockHeight: 620999), repository: pendingRespository)
        
        let submitExpect = XCTestExpectation(description: "submit")
        guard let tx = submittableTx() else {
            XCTFail("failed to encode and all that")
            return
        }
        
        
        transactionManager.submit(pendingTransaction: tx) { (result) in
            submitExpect.fulfill()
            switch result {
            case .failure(_):
                let failedTx = try? self.pendingRespository.find(by: tx.id!)
                XCTAssertTrue(failedTx?.isFailedSubmit ?? false)
            case .success(_):
                XCTFail("test should have failed but succeeeded!")
            }
            
        }
        wait(for: [submitExpect], timeout: 5)
        
        
    }
    private func submittableTx() -> PendingTransactionEntity? {
        let encodeExpect = XCTestExpectation(description: "encode")
        
        
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return nil
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
        wait(for: [encodeExpect], timeout: 20)
        
        guard let submittableTx = encodedTx else {
            XCTFail("failed to encode tx")
            return nil
        }
        return submittableTx
    }
    
    
    func testSubmit() {
        let submitExpect = XCTestExpectation(description: "submit")
        guard let tx = submittableTx() else {
            XCTFail("failed to encode and all that")
            return
        }
        
        
        transactionManager.submit(pendingTransaction: tx) { (result) in
            submitExpect.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("submission failed with error: \(error)")
                let failedTx = try? self.pendingRespository.find(by: tx.id!)
                XCTAssertTrue(failedTx?.isFailedSubmit ?? false)
            case .success(let successfulTx):
                XCTAssertEqual(tx.id, successfulTx.id)
                XCTAssertTrue(successfulTx.isSubmitted)
                XCTAssertTrue(successfulTx.isSubmitSuccess)
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
        
        var minedTransaction: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { minedTransaction = try transactionManager.applyMinedHeight(pendingTransaction: pendingTx, minedHeight: minedHeight)}())
        
        guard let minedTx = minedTransaction else {
            XCTFail("failed to apply mined height")
            return
        }
        XCTAssertTrue(minedTx.isMined)
        XCTAssertEqual(minedTx.minedHeight, minedHeight)
        
    }
    
    func testCancel() {
        
        var tx: PendingTransactionEntity?
        
        XCTAssertNoThrow(try { tx = try transactionManager.initSpend(zatoshi: zpend, toAddress: recipientAddress, memo: nil, from: 0) }())
        
        guard let pendingTx = tx else {
            XCTFail("failed to create pending transaction")
            return
        }
        
        let cancellationResult = transactionManager.cancel(pendingTransaction: pendingTx)
        
        guard let id = pendingTx.id else {
            XCTFail("transaction with no id")
            return
        }
        guard let retrievedTransaction = try! pendingRespository.find(by: id) else {
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
}
