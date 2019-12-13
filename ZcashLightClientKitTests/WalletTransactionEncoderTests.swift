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
    let zpend: Int = 1_000
    let queue: OperationQueue = OperationQueue()
    
    override func setUp() {
        try! dataDbHandle.setUp()
        try! cacheDbHandle.setUp()
        
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        
        initializer = Initializer(cacheDbURL: cacheDbHandle.readWriteDb, dataDbURL: dataDbHandle.readWriteDb, pendingDbURL: try! TestDbBuilder.pendingTransactionsDbURL(), endpoint: LightWalletEndpointBuilder.default, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
        
        repository = TransactionSQLDAO(dbProvider: dataDbHandle.connectionProvider(readwrite: false))
        transactionEncoder = WalletTransactionEncoder(initializer:  initializer)
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
    
    
    func testOperation() {
        
        let expect = XCTestExpectation(description: self.description)
        let operation = SpendOperation(rust: rustBackend, spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil, from: 0, dataDbURL: dataDbHandle.readWriteDb, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
        operation.completionBlock = {
            expect.fulfill()
            XCTAssertTrue(operation.txId > 0)
        }
        queue.addOperation(operation)
        
        wait(for: [expect], timeout: 500)
        
    }
    
    func testStandaloneOperation() {
        
        let operation = SpendOperation(rust: rustBackend, spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil, from: 0, dataDbURL: dataDbHandle.readWriteDb, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
        operation.main()
        XCTAssertTrue(operation.txId > 0)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            do {
                _ = try transactionEncoder.createSpend(spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil, from: 0)
            } catch {
                XCTFail("error: \(error)")
            }
        }
    }
    
    func testSpendThread() {
        let operation = CreateToAddressThread(rust: rustBackend, spendingKey: self.spendingKey, zatoshi: self.zpend, to: self.recipientAddress, memo: nil, from: 0, dataDbURL: dataDbHandle.readWriteDb, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
        
        operation.start()
        while (operation.isExecuting) {
            sleep(1)
        }
        
        
        XCTAssertTrue(operation.txId > 0)
    }
    
    func testSpendGlobalQueue() {
        var txId: Int64 = -1
        let expectation = XCTestExpectation(description: self.description)
        DispatchQueue.global().async {
            txId = self.rustBackend.createToAddress(dbData: self.dataDbHandle.readWriteDb,
                                                account: 0,
                                                extsk: self.spendingKey,
                                                to: self.recipientAddress,
                                                value: Int64(self.zpend),
                                                memo: nil,
                                                spendParams:  try! __spendParamsURL(),
                                                outputParams: try! __outputParamsURL())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 240)
        XCTAssertTrue(txId >= 0)
    }
    
}


class SpendOperation: Operation {
    override var isConcurrent: Bool {
        false
    }
    override var isAsynchronous: Bool {
        false
    }
    
    private var rustBackend: ZcashRustBackendWelding.Type
    private var spendingKey: String
    private var zatoshi: Int
    private var recipient: String
    private var memo: String?
    private var fromAccount: Int
    private var spendURL: URL
    private var outputURL: URL
    private var dataDbURL: URL
    
    var txId: Int64 = -1
    init(rust: ZcashRustBackendWelding.Type, spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int, dataDbURL: URL, spendParamsURL: URL, outputParamsURL: URL) {
        self.rustBackend = rust
        self.spendingKey = spendingKey
        self.zatoshi = zatoshi
        self.recipient = to
        self.memo = memo
        self.fromAccount = accountIndex
        self.spendURL = spendParamsURL
        self.outputURL = outputParamsURL
        self.dataDbURL = dataDbURL
    }
    
    override func main() {
        
        txId = rustBackend.createToAddress(dbData: dataDbURL, account: Int32(fromAccount), extsk: spendingKey, to: recipient, value: Int64(zatoshi), memo: memo, spendParams: spendURL, outputParams: outputURL)
        
    }
    
}


class CreateToAddressThread: Thread {
    
    private var rustBackend: ZcashRustBackendWelding.Type
    private var spendingKey: String
    private var zatoshi: Int
    private var recipient: String
    private var memo: String?
    private var fromAccount: Int
    private var spendURL: URL
    private var outputURL: URL
    private var dataDbURL: URL
    override var isExecuting: Bool {
        _working
    }
    
    private var _working: Bool = true
    var txId: Int64 = -1
    init(rust: ZcashRustBackendWelding.Type, spendingKey: String, zatoshi: Int, to: String, memo: String?, from accountIndex: Int, dataDbURL: URL, spendParamsURL: URL, outputParamsURL: URL) {
        self.rustBackend = rust
        self.spendingKey = spendingKey
        self.zatoshi = zatoshi
        self.recipient = to
        self.memo = memo
        self.fromAccount = accountIndex
        self.spendURL = spendParamsURL
        self.outputURL = outputParamsURL
        self.dataDbURL = dataDbURL
    }
    
    override func main() {
        self._working = true
        
        txId = rustBackend.createToAddress(dbData: dataDbURL, account: Int32(fromAccount), extsk: spendingKey, to: recipient, value: Int64(zatoshi), memo: memo, spendParams: spendURL, outputParams: outputURL)
        self._working = false
    }
}
