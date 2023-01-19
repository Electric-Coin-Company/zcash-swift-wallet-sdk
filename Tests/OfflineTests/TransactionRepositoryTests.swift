//
//  TransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/16/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping force_try
class TransactionRepositoryTests: XCTestCase {
    var transactionRepository: TransactionRepository!
    
    override func setUp() {
        super.setUp()

        transactionRepository = try! TestDbBuilder.transactionRepository()
    }
    
    override func tearDown() {
        super.tearDown()
        transactionRepository = nil
    }
    
    func testCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countAll() }())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 21)
    }
    
    func testCountUnmined() {
        var count: Int?
        XCTAssertNoThrow(try { count = try self.transactionRepository.countUnmined() }())
        XCTAssertNotNil(count)
        XCTAssertEqual(count, 0)
    }

    func testBlockForHeight() {
        var block: Block!
        XCTAssertNoThrow(try { block = try self.transactionRepository.blockForHeight(663150) }())
        XCTAssertEqual(block.height, 663150)
    }

    func testLastScannedHeight() {
        var height: BlockHeight!
        XCTAssertNoThrow(try { height = try self.transactionRepository.lastScannedHeight() }())
        XCTAssertEqual(height, 665000)
    }

    func testFindInRange() {
        var transactions: [Transaction.Overview]!
        XCTAssertNoThrow(
            try {
                transactions = try self.transactionRepository.find(in: BlockRange(startHeight: 663218, endHeight: 663974), limit: 3, kind: .received)
            }()
        )

        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 663974)
        XCTAssertEqual(transactions[0].isSentTransaction, false)
        XCTAssertEqual(transactions[1].minedHeight, 663953)
        XCTAssertEqual(transactions[1].isSentTransaction, false)
        XCTAssertEqual(transactions[2].minedHeight, 663229)
        XCTAssertEqual(transactions[2].isSentTransaction, false)
    }
    
    func testFindById() {
        var transaction: Transaction.Overview!
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.find(id: 10) }())

        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.minedHeight, 663942)
        XCTAssertEqual(transaction.index, 5)
    }
    
    func testFindByTxId() {
        var transaction: Transaction.Overview!

        let id = Data(fromHexEncodedString: "01af48bcc4e9667849a073b8b5c539a0fc19de71aac775377929dc6567a36eff")!
        
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.find(rawID: id) }())

        XCTAssertEqual(transaction.id, 8)
        XCTAssertEqual(transaction.minedHeight, 663922)
        XCTAssertEqual(transaction.index, 1)
    }
    
    func testFindAllSentTransactions() {
        var transactions: [Transaction.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .sent) }())
        XCTAssertEqual(transactions.count, 13)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, true) }
    }
    
    func testFindAllReceivedTransactions() {
        var transactions: [Transaction.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .received) }())
        XCTAssertEqual(transactions.count, 8)
        transactions.forEach { XCTAssertEqual($0.isSentTransaction, false) }
    }
    
    func testFindAllTransactions() {
        var transactions: [Transaction.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all) }())
        XCTAssertEqual(transactions.count, 21)
    }

    func testFindReceivedOffsetLimit() {
        var transactions: [Transaction.Received] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findReceived(offset: 3, limit: 3) }())

        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 664022)
        XCTAssertEqual(transactions[1].minedHeight, 664012)
        XCTAssertEqual(transactions[2].minedHeight, 664003)
    }

    func testFindSentOffsetLimit() {
        var transactions: [Transaction.Sent] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.findSent(offset: 3, limit: 3) }())

        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].minedHeight, 664022)
        XCTAssertEqual(transactions[1].minedHeight, 664012)
        XCTAssertEqual(transactions[2].minedHeight, 663956)
    }

    func testFindMemoForTransaction() {
        let transaction = Transaction.Overview(
            blockTime: nil,
            expiryHeight: nil,
            fee: nil,
            id: 9,
            index: nil,
            isWalletInternal: false,
            hasChange: false,
            memoCount: 0,
            minedHeight: nil,
            raw: nil,
            rawID: Data(),
            receivedNoteCount: 0,
            sentNoteCount: 0,
            value: Zatoshi.zero
        )

        var memos: [Memo]!
        XCTAssertNoThrow(try { memos = try self.transactionRepository.findMemos(for: transaction) }())

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].toString(), "Some funds")
    }

    func testFindMemoForReceivedTransaction() {
        let transaction = Transaction.Received(
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

        var memos: [Memo]!
        XCTAssertNoThrow(try { memos = try self.transactionRepository.findMemos(for: transaction) }())

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].toString(), "Some funds")
    }

    func testFindMemoForSentTransaction() {
        let transaction = Transaction.Sent(
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

        var memos: [Memo]!
        XCTAssertNoThrow(try { memos = try self.transactionRepository.findMemos(for: transaction) }())

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].toString(), "Some funds")
    }

    func testFindTransactionWithNULLMinedHeight() {
        var transactions: [Transaction.Overview] = []
        XCTAssertNoThrow(try { transactions = try self.transactionRepository.find(offset: 0, limit: 3, kind: .all) }())

        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(transactions[0].id, 21)
        XCTAssertEqual(transactions[0].minedHeight, nil)
        XCTAssertEqual(transactions[1].id, 20)
        XCTAssertEqual(transactions[1].minedHeight, 664037)
        XCTAssertEqual(transactions[2].id, 19)
        XCTAssertEqual(transactions[2].minedHeight, 664022)
    }
    
    func testFindAllPerformance() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            do {
                _ = try self.transactionRepository.find(offset: 0, limit: Int.max, kind: .all)
            } catch {
                XCTFail("find all failed")
            }
        }
    }
    
    func testFindAllFrom() throws {
        var transaction: Transaction.Overview!
        XCTAssertNoThrow(try { transaction = try self.transactionRepository.find(id: 16) }())

        var transactionsFrom: [Transaction.Overview] = []
        XCTAssertNoThrow(try { transactionsFrom = try self.transactionRepository.find(from: transaction, limit: Int.max, kind: .all) }())

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
