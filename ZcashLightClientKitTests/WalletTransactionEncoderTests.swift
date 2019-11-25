//
//  WalletTransactionEncoderTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/20/19.
//

import XCTest
@testable import ZcashLightClientKit
class WalletTransactionEncoderTests: XCTestCase {

    var repository: TransactionRepository!
    var rustBackend = ZcashRustBackend.self
    var transactionEncoder: WalletTransactionEncoder!
    var dataDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedDataDbURL()!)
    var cacheDbHandle = TestDbHandle(originalDb: TestDbBuilder.prePopulatedCacheDbURL()!)
    var initializer: Initializer!
    let spendingKey = "zxviewtestsapling1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhszsdmllvgjs754hua7yy7k2fpgx6rntp4td5axj5ej82rgt3hcn90lq59l8nh0uzjuazfradarnr6nmn3mw63jq00ggw69wg0z3tvm9q5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcqs0rwac"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    
    let zpend: Int64 = 500_000
    
    override func setUp() {
        try! dataDbHandle.setUp()
        try! cacheDbHandle.setUp()
        initializer = Initializer(cacheDbURL: cacheDbHandle.readWriteDb, dataDbURL: dataDbHandle.readWriteDb, endpoint: LightWalletEndpointBuilder.default, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
        repository = TransactionSQLDAO(dbProvider: dataDbHandle.connectionProvider(readwrite: false))
        transactionEncoder = WalletTransactionEncoder(rust: rustBackend.self, repository: repository, initializer:  initializer)
    }

    override func tearDown() {
        repository = nil
        dataDbHandle.dispose()
        cacheDbHandle.dispose()
    }

    func testCreateTransaction() {
        var transaction: EncodedTransaction?
        XCTAssertNoThrow(try { transaction = try transactionEncoder.createTransaction(spendingKey: spendingKey, zatoshi: zpend, to: recipientAddress, memo: nil, from: 0)}())
        guard let tx = transaction else {
            XCTFail("transaction is nil")
            return
        }
        
        var retrievedTx: TransactionEntity?
        XCTAssertNoThrow(try { retrievedTx = try repository.findBy(rawId: tx.transactionId) }())
        
        XCTAssertNotNil(retrievedTx, "transaction not found")
    }
    
    func testCreateSpend() {
        
        XCTAssert(initializer.getBalance() >= zpend)
    
        var spendId: Int64?
        
        XCTAssertNoThrow(try { spendId = try transactionEncoder.createSpend(spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil,  from: 0) }())
        
        guard let id = spendId else {
            XCTFail("failed to create spend")
            return
        }
        
        var tx: TransactionEntity?
        XCTAssertNoThrow(try { tx = try repository.findBy(id: id)}())
        XCTAssertNotNil(tx)
        
    }
    
    

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
