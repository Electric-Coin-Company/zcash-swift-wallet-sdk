//
//  MockTransactionRepository.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 12/6/19.
//

import Foundation

@testable import ZcashLightClientKit

class MockTransactionRepository: TransactionRepository {
    func findTransactions(in range: BlockRange, limit: Int) throws -> [TransactionEntity]? {
        nil
    }
    
//    func findTransactions(in range: BlockRange, limit: Int) throws -> [TransactionEntity]? {
//        nil
//    }
    
    
    var unminedCount: Int
    var receivedCount: Int
    var sentCount: Int
    
    var transactions: [ConfirmedTransactionEntity] = []
    var reference: [Kind] = []
    var sentTransactions: [ConfirmedTransaction] = []
    var receivedTransactions: [ConfirmedTransaction] = []
    
    var allCount: Int {
        receivedCount + sentCount
    }
    
    init(unminedCount: Int, receivedCount: Int, sentCount: Int) {
        self.unminedCount = unminedCount
        self.receivedCount = receivedCount
        self.sentCount = sentCount
    }
    
    func generate() {
        
        var txArray = [ConfirmedTransactionEntity]()
        reference = referenceArray()
        for i in 0 ..< reference.count {
            txArray.append(mockTx(index: i, kind: reference[i]))
        }
        transactions = txArray
    }
    
    func countAll() throws -> Int {
        allCount
    }
    
    func countUnmined() throws -> Int {
        unminedCount
    }
    
    func findBy(id: Int) throws -> TransactionEntity? {
        transactions.first(where: {$0.id == id})?.transactionEntity
    }
    
    func findBy(rawId: Data) throws -> TransactionEntity? {
        transactions.first(where: {$0.rawTransactionId == rawId})?.transactionEntity
    }
    
    func findAllSentTransactions(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]? {
        guard let indices = reference.indices(where: { $0 == .sent }) else { return nil }
        
        let sentTxs = indices.map { (idx) -> ConfirmedTransactionEntity in
            transactions[idx]
        }
        return slice(txs: sentTxs, offset: offset, limit: limit)
    }
    
    
    func findAllReceivedTransactions(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]? {
          guard let indices = reference.indices(where: { $0 == .received }) else { return nil }
              
        let receivedTxs = indices.map { (idx) -> ConfirmedTransactionEntity in
                  transactions[idx]
              }
        return slice(txs: receivedTxs, offset: offset, limit: limit)
    }
    
    func findAll(offset: Int, limit: Int) throws -> [ConfirmedTransactionEntity]? {
        transactions
    }
    
    func lastScannedHeight() throws -> BlockHeight {
        return 700000
    }
    
    func isInitialized() throws -> Bool {
        true
    }
    
    func findEncodedTransactionBy(txId: Int) -> EncodedTransaction? {
        nil
    }
    
    enum Kind {
        case sent
        case received
    }
    
    func referenceArray() -> [Kind] {
        var template = [Kind]()
        
        for _ in 0 ..< sentCount {
            template.append(.sent)
        }
        for _ in 0 ..< receivedCount {
            template.append(.received)
        }
        return template.shuffled()
    }
    
    
    func mockTx(index: Int, kind: Kind) -> ConfirmedTransactionEntity {
        switch kind {
        case .received:
            return mockReceived(index)
        case .sent:
            return mockSent(index)
        }
    }
    
    func mockSent(_ index: Int) -> ConfirmedTransactionEntity {
        ConfirmedTransaction(toAddress: "some_address", expiryHeight: BlockHeight.max, minedHeight: randomBlockHeight(), noteId: index, blockTimeInSeconds: randomTimeInterval(), transactionIndex: index, raw: Data(), id: index, value: Int.random(in: 1 ... ZcashSDK.ZATOSHI_PER_ZEC), memo: nil, rawTransactionId: Data())
    }
    
    
    func mockReceived(_ index: Int) -> ConfirmedTransactionEntity {
         ConfirmedTransaction(toAddress: nil, expiryHeight: BlockHeight.max, minedHeight: randomBlockHeight(), noteId: index, blockTimeInSeconds: randomTimeInterval(), transactionIndex: index, raw: Data(), id: index, value: Int.random(in: 1 ... ZcashSDK.ZATOSHI_PER_ZEC), memo: nil, rawTransactionId: Data())
    }
    
    func randomBlockHeight() -> BlockHeight {
        BlockHeight.random(in: ZcashSDK.SAPLING_ACTIVATION_HEIGHT ... 1_000_000)
    }
    func randomTimeInterval() -> TimeInterval {
        Double.random(in: Date().timeIntervalSince1970 - 1000000.0 ... Date().timeIntervalSince1970)
    }
    
    func slice(txs: [ConfirmedTransactionEntity], offset: Int, limit: Int) -> [ConfirmedTransactionEntity] {
        guard offset < txs.count else { return [] }
        
        return Array(txs[offset ..< min(offset + limit, txs.count - offset)])
    }
}

extension MockTransactionRepository.Kind: Equatable {}

extension Array {
    func indices(where f: (_ element: Element) -> Bool) -> [Int]? {
        guard self.count > 0 else { return nil }
        var idx = [Int]()
        for i in 0 ..< self.count {
            if f(self[i]) {
                idx.append(i)
            }
        }
        
        guard idx.count > 0 else { return nil }
        return idx
        
    }
}
