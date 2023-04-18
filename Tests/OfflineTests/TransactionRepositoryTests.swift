//
//  TransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/16/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class TransactionRepositoryTests: XCTestCase {
    var transactionRepository: TransactionRepository!

    override func setUp() async throws {
        try await super.setUp()
        let rustBackend = ZcashRustBackend.makeForTests(fsBlockDbRoot: Environment.uniqueTestTempDirectory, networkType: .testnet)
        transactionRepository = try! await TestDbBuilder.transactionRepository(rustBackend: rustBackend)
    }
    
    override func tearDown() {
        super.tearDown()
        transactionRepository = nil
    }
    
    func testCount() async throws {
        let count = try await self.transactionRepository.countAll()
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 21)
    }
    
    func testCountUnmined() async throws {
        let count = try await self.transactionRepository.countUnmined()
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 0)
    }

    func testBlockForHeight() async throws {
        let block = try await self.transactionRepository.blockForHeight(663150)
        XCTAssertEqual(block?.height, 663150)
    }

    func testLastScannedHeight() async throws {
        let height = try await self.transactionRepository.lastScannedHeight()
        XCTAssertEqual(height, 665000)
    }

    func testFindInRange() async throws {
        let transactions = try await self.transactionRepository.find(in: 663218...663974, limit: 3, kind: .received)
        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 663974)
        XCTAssertEqual(transactions[0].isSentTransaction, false)
        XCTAssertEqual(transactions[1].minedHeight, 663953)
        XCTAssertEqual(transactions[1].isSentTransaction, false)
        XCTAssertEqual(transactions[2].minedHeight, 663229)
        XCTAssertEqual(transactions[2].isSentTransaction, false)
    }
    
    func testFindById() async throws {
        let transaction = try await self.transactionRepository.find(id: 10)
        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 663942)
        XCTAssertEqual(transaction.index, 5)
    }
    
    func testFindByTxId() async throws {
        let id = Data(fromHexEncodedString: "01af48bcc4e9667849a073b8b5c539a0fc19de71aac775377929dc6567a36eff")!
        let transaction = try await self.transactionRepository.find(rawID: id)
        XCTAssertEqual(transaction.id, 8)
        XCTAssertEqual(transaction.minedHeight, 663922)
        XCTAssertEqual(transaction.index, 1)
    }
    
    func testFindAllSentTransactions() async throws {
        let transactions = try await self.transactionRepository.find(offset: 0, limit: Int.max, kind: .sent)
        XCTAssertEqual(transactions.count, 13)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, true) }
    }
    
    func testFindAllReceivedTransactions() async throws {
        let transactions = try await self.transactionRepository.find(offset: 0, limit: Int.max, kind: .received)
        XCTAssertEqual(transactions.count, 8)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, false) }
    }
    
    func testFindAllTransactions() async throws {
        let transactions = try await self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
        XCTAssertEqual(transactions.count, 21)
    }

    func testFindReceivedOffsetLimit() async throws {
        let transactions = try await self.transactionRepository.findReceived(offset: 3, limit: 3)
        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 663229)
        XCTAssertEqual(transactions[1].minedHeight, 663218)
        XCTAssertEqual(transactions[2].minedHeight, 663202)
    }

    func testFindSentOffsetLimit() async throws {
        let transactions = try await self.transactionRepository.findSent(offset: 3, limit: 3)
        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 664022)
        XCTAssertEqual(transactions[1].minedHeight, 664012)
        XCTAssertEqual(transactions[2].minedHeight, 663956)
    }

    func testFindMemoForTransaction() async throws {
        let transaction = ZcashTransaction.Overview(
            accountId: 0,
            blockTime: nil,
            expiryHeight: nil,
            fee: nil,
            id: 9,
            index: nil,
            hasChange: false,
            memoCount: 0,
            minedHeight: nil,
            raw: nil,
            rawID: Data(),
            receivedNoteCount: 0,
            sentNoteCount: 0,
            value: Zatoshi(-1000),
            isExpiredUmined: false
        )

        let memos = try await self.transactionRepository.findMemos(for: transaction)

        guard memos.count == 1 else {
            XCTFail("Expected transaction to have one memo")
            return
        }

        XCTAssertEqual(memos[0].toString(), "Some funds")
    }

    func testFindMemoForReceivedTransaction() async throws {
        let transaction = ZcashTransaction.Received(
            blockTime: 1,
            expiryHeight: nil,
            fromAccount: 0,
            id: 5,
            index: 0,
            memoCount: 0,
            minedHeight: 0,
            noteCount: 0,
            raw: nil,
            rawID: nil,
            value: Zatoshi.zero
        )

        let memos = try await self.transactionRepository.findMemos(for: transaction)
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].toString(), "first mainnet tx from the SDK")
    }

    func testFindMemoForSentTransaction() async throws {
        let transaction = ZcashTransaction.Sent(
            blockTime: 1,
            expiryHeight: nil,
            fromAccount: 0,
            id: 9,
            index: 0,
            memoCount: 0,
            minedHeight: 0,
            noteCount: 0,
            raw: nil,
            rawID: nil,
            value: Zatoshi.zero
        )

        let memos = try await self.transactionRepository.findMemos(for: transaction)
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].toString(), "Some funds")
    }
    
    func testFindAllPerformance() {
        // This is an example of a performance test case.
        self.measure {
            let expectation = expectation(description: "Measure")
            Task(priority: .userInitiated) {
                // Put the code you want to measure the time of here.
                do {
                    _ = try await self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
                    expectation.fulfill()
                } catch {
                    XCTFail("find all failed")
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testFindAllFrom() async throws {
        let transaction = try await self.transactionRepository.find(id: 16)
        let transactionsFrom = try await self.transactionRepository.find(from: transaction, limit: Int.max, kind: .all)

        XCTAssertEqual(transactionsFrom.count, 8)

        transactionsFrom.forEach { preceededTransaction in
            guard let preceededTransactionIndex = preceededTransaction.index, let transactionIndex = transaction.index else {
                XCTFail("Transactions are missing indexes.")
                return
            }

            guard let preceededTransactionBlockTime = preceededTransaction.blockTime, let transactionBlockTime = transaction.blockTime else {
                XCTFail("Transactions are missing block time.")
                return
            }

            XCTAssertLessThan(preceededTransactionIndex, transactionIndex)
            XCTAssertLessThan(preceededTransactionBlockTime, transactionBlockTime)
        }
    }
}

extension Data {
    init?(fromHexEncodedString string: String) {
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(bytes: UInt16) -> UInt8? {
            switch bytes {
            case 0x30 ... 0x39:
                return UInt8(bytes - 0x30)
            case 0x41 ... 0x46:
                return UInt8(bytes - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(bytes - 0x61 + 10)
            default:
                return nil
            }
        }

        self.init(capacity: string.utf16.count / 2)
        var even = true
        var byte: UInt8 = 0
        for char in string.utf16 {
            guard let val = decodeNibble(bytes: char) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even.toggle()
        }
        guard even else { return nil }
    }
}
