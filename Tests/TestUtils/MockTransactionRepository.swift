//
//  MockTransactionRepository.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 12/6/19.
//

import Foundation
@testable import ZcashLightClientKit

enum MockTransactionRepositoryError: Error {
    case notImplemented
}

class MockTransactionRepository {
    enum Kind {
        case sent
        case received
    }

    var unminedCount: Int
    var receivedCount: Int
    var sentCount: Int
    var scannedHeight: BlockHeight
    var reference: [Kind] = []
    var network: ZcashNetwork

    var transactions: [ZcashTransaction.Overview] = []
    var receivedTransactions: [ZcashTransaction.Received] = []
    var sentTransactions: [ZcashTransaction.Sent] = []

    var allCount: Int {
        receivedCount + sentCount
    }

    init(
        unminedCount: Int,
        receivedCount: Int,
        sentCount: Int,
        scannedHeight: BlockHeight,
        network: ZcashNetwork
    ) {
        self.unminedCount = unminedCount
        self.receivedCount = receivedCount
        self.sentCount = sentCount
        self.scannedHeight = scannedHeight
        self.network = network
    }

    func referenceArray() -> [Kind] {
        var template: [Kind] = []
        
        for _ in 0 ..< sentCount {
            template.append(.sent)
        }
        for _ in 0 ..< receivedCount {
            template.append(.received)
        }

        return template.shuffled()
    }
    
    func randomBlockHeight() -> BlockHeight {
        BlockHeight.random(in: network.constants.saplingActivationHeight ... 1_000_000)
    }

    func randomTimeInterval() -> TimeInterval {
        Double.random(in: Date().timeIntervalSince1970 - 1000000.0 ... Date().timeIntervalSince1970)
    }
}

extension MockTransactionRepository.Kind: Equatable {}

// MARK: - TransactionRepository
extension MockTransactionRepository: TransactionRepository {
    func getRecipients(for id: Int) -> [TransactionRecipient] {
        []
    }

    func closeDBConnection() { }

    func countAll() throws -> Int {
        allCount
    }

    func countUnmined() throws -> Int {
        unminedCount
    }

    func blockForHeight(_ height: BlockHeight) throws -> Block? {
        nil
    }

    func findBy(id: Int) throws -> ZcashTransaction.Overview? {
        transactions.first(where: { $0.id == id })
    }

    func findBy(rawId: Data) throws -> ZcashTransaction.Overview? {
        transactions.first(where: { $0.rawID == rawId })
    }

    func lastScannedHeight() throws -> BlockHeight {
        scannedHeight
    }

    func lastScannedBlock() throws -> Block? {
        nil
    }

    func isInitialized() throws -> Bool {
        true
    }

    func generate() {
        var txArray: [ZcashTransaction.Overview] = []
        reference = referenceArray()
        for index in 0 ..< reference.count {
            txArray.append(mockTx(index: index, kind: reference[index]))
        }
        transactions = txArray
    }

    func mockTx(index: Int, kind: Kind) -> ZcashTransaction.Overview {
        switch kind {
        case .received:
            return mockReceived(index)
        case .sent:
            return mockSent(index)
        }
    }

    func mockSent(_ index: Int) -> ZcashTransaction.Overview {
        return ZcashTransaction.Overview(
            blockTime: randomTimeInterval(),
            expiryHeight: BlockHeight.max,
            fee: Zatoshi(2),
            id: index,
            index: index,
            isWalletInternal: true,
            hasChange: true,
            memoCount: 0,
            minedHeight: randomBlockHeight(),
            raw: Data(),
            rawID: Data(),
            receivedNoteCount: 0,
            sentNoteCount: 1,
            value: Zatoshi(-Int64.random(in: 1 ... Zatoshi.Constants.oneZecInZatoshi))
        )
    }

    func mockReceived(_ index: Int) -> ZcashTransaction.Overview {
        return ZcashTransaction.Overview(
            blockTime: randomTimeInterval(),
            expiryHeight: BlockHeight.max,
            fee: Zatoshi(2),
            id: index,
            index: index,
            isWalletInternal: true,
            hasChange: true,
            memoCount: 0,
            minedHeight: randomBlockHeight(),
            raw: Data(),
            rawID: Data(),
            receivedNoteCount: 1,
            sentNoteCount: 0,
            value: Zatoshi(Int64.random(in: 1 ... Zatoshi.Constants.oneZecInZatoshi))
        )
    }

    func slice(txs: [ZcashTransaction.Overview], offset: Int, limit: Int) -> [ZcashTransaction.Overview] {
        guard offset < txs.count else { return [] }

        return Array(txs[offset ..< min(offset + limit, txs.count - offset)])
    }

    func find(id: Int) throws -> ZcashTransaction.Overview {
        guard let transaction = transactions.first(where: { $0.id == id }) else {
            throw TransactionRepositoryError.notFound
        }

        return transaction
    }

    func find(rawID: Data) throws -> ZcashTransaction.Overview {
        guard let transaction = transactions.first(where: { $0.rawID == rawID }) else {
            throw TransactionRepositoryError.notFound
        }

        return transaction
    }

    func find(offset: Int, limit: Int, kind: TransactionKind) throws -> [ZcashLightClientKit.ZcashTransaction.Overview] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) throws -> [ZcashTransaction.Overview] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) throws -> [ZcashTransaction.Overview] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func findReceived(offset: Int, limit: Int) throws -> [ZcashTransaction.Received] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func findSent(offset: Int, limit: Int) throws -> [ZcashTransaction.Sent] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func findMemos(for transaction: ZcashLightClientKit.ZcashTransaction.Overview) throws -> [ZcashLightClientKit.Memo] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func findMemos(for receivedTransaction: ZcashLightClientKit.ZcashTransaction.Received) throws -> [ZcashLightClientKit.Memo] {
        throw MockTransactionRepositoryError.notImplemented
    }

    func findMemos(for sentTransaction: ZcashLightClientKit.ZcashTransaction.Sent) throws -> [ZcashLightClientKit.Memo] {
        throw MockTransactionRepositoryError.notImplemented
    }
}

extension Array {
    func indices(where function: (_ element: Element) -> Bool) -> [Int]? {
        guard !self.isEmpty else { return nil }

        var idx: [Int] = []

        for index in 0 ..< self.count where function(self[index]) {
            idx.append(index)
        }
        
        guard !idx.isEmpty else { return nil }
        return idx
    }
}
