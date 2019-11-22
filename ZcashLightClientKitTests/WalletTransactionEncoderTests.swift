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
    let spendingKey = "zxviewtestsapling1qwxyzvdmqqqqpqy3knx32fpja779wzg76kmglgguvr74g773f3aw3gy37rar6y9d37knvskz6thnea55s05cz3a7q38835hq4w58yevn763cn2wf7k2mpj247ynxpt9qm0nn39slkz5dk572hxr43pxqtg5kz3pqcj8z8uhz0l2vx8gxe90uf4pgw7ks23f0hz2hm47k9ym42cmns3tenhxzlyur2nvx68h4fmk9nrs44ymcqz434zsuxpvhklrjzn00gc43fdghn5szc5x2w"
    let recipientAddress = "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6"
    
    override func setUp() {
        try! dataDbHandle.setUp()
        try! cacheDbHandle.setUp()
        initializer = Initializer(cacheDbURL: cacheDbHandle.readWriteDb, dataDbURL: dataDbHandle.readWriteDb, endpoint: LightWalletEndpointBuilder.default)
        repository = TransactionSQLDAO(dbProvider: dataDbHandle.connectionProvider(readwrite: false))
        transactionEncoder = WalletTransactionEncoder(rust: rustBackend.self, repository: repository)
    }

    override func tearDown() {
        repository = nil
        dataDbHandle.dispose()
        cacheDbHandle.dispose()
    }

    func testCreateTransaction() {
        var transaction: EncodedTransaction?
        XCTAssertNoThrow(try { transaction = try transactionEncoder.createTransaction(spendingKey: spendingKey, zatoshi: 500_000, to: recipientAddress, memo: nil, from: 0)}())
        guard let tx = transaction else {
            XCTFail("transaction is nil")
            return
        }
        
        var retrievedTx: TransactionEntity?
        XCTAssertNoThrow(try { retrievedTx = try repository.findBy(rawId: tx.transactionId) }())
        
        XCTAssertNotNil(retrievedTx, "transaction not found")
    }
    
    func testCreateSpend() {
        var spendId: Int64?
        spendId = transactionEncoder.createSpend(spendingKey: spendingKey, zatoshi: 500_000, to: recipientAddress, memo: nil , from: 0)
        
        guard let id = spendId else {
            XCTFail("failed to create spend")
            return
        }
        
        var tx: TransactionEntity?
        XCTAssertNoThrow(try { tx = try repository.findBy(id: Int(id))}())
        
        XCTAssertNotNil(tx)
        
    }
    
    func testEnsureParams() {
        XCTFail()
    }
    
    

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
