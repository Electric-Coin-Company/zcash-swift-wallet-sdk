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
    let spendingKey = "secret-extended-key-test1qvpevftsqqqqpqy52ut2vv24a2qh7nsukew7qg9pq6djfwyc3xt5vaxuenshp2hhspp9qmqvdh0gs2ljpwxders5jkwgyhgln0drjqaguaenfhehz4esdl4kwlm5t9q0l6wmzcrvcf5ed6dqzvct3e2ge7f6qdvzhp02m7sp5a0qjssrwpdh7u6tq89hl3wchuq8ljq8r8rwd6xdwh3nry9at80z7amnj3s6ah4jevnvfr08gxpws523z95g6dmn4wm6l3658kd4xcq9rc0qn"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    let zpend: Int = 500_000
    
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
            XCTFail("transaction is nil. error: \(String(describing: rustBackend.getLastError()))")
            return
        }
        
        var retrievedTx: TransactionEntity?
        XCTAssertNoThrow(try { retrievedTx = try repository.findBy(rawId: tx.transactionId) }())
        
        XCTAssertNotNil(retrievedTx, "transaction not found")
    }
    
    func testCreateSpend() {
        
        XCTAssert(initializer.getBalance() >= zpend)
    
        var spendId: Int?
        
        XCTAssertNoThrow(try { spendId = try transactionEncoder.createSpend(spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil,  from: 0) }())
        
        guard let id = spendId else {
            XCTFail("failed to create spend. error: \(String(describing: rustBackend.getLastError()))")
            return
        }
        
        var tx: TransactionEntity?
        XCTAssertNoThrow(try { tx = try repository.findBy(id: id)}())
        XCTAssertNotNil(tx, "Transaction Id: \(id), not found. rust error: \(String(describing: rustBackend.getLastError()))")
        
    }
    
    

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
             _ = try! transactionEncoder.createSpend(spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil, from: 0)
        }
    }

}
