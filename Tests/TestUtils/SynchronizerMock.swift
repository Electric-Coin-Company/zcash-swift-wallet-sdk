//
//  SynchronizerMock.swift
//  
//
//  Created by Michal Fousek on 20.03.2023.
//

import Combine
import Foundation
@testable import ZcashLightClientKit

class SynchronizerMock: Synchronizer {
    init() { }

    var underlyingAlias: ZcashSynchronizerAlias! = nil
    var alias: ZcashLightClientKit.ZcashSynchronizerAlias { underlyingAlias }

    var underlyingStateStream: AnyPublisher<SynchronizerState, Never>! = nil
    var stateStream: AnyPublisher<SynchronizerState, Never> { underlyingStateStream }

    var underlyingLatestState: SynchronizerState! = nil
    var latestState: SynchronizerState { underlyingLatestState }

    var underlyingEventStream: AnyPublisher<SynchronizerEvent, Never>! = nil
    var eventStream: AnyPublisher<SynchronizerEvent, Never> { underlyingEventStream }

    var underlyingConnectionState: ConnectionState! = nil
    var connectionState: ConnectionState { underlyingConnectionState }

    let metrics = SDKMetrics()
    
    var prepareWithSeedViewingKeysWalletBirthdayClosure: (
        ([UInt8]?, [UnifiedFullViewingKey], BlockHeight) async throws -> Initializer.InitializationResult
    )! = nil
    func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) async throws -> Initializer.InitializationResult {
        return try await prepareWithSeedViewingKeysWalletBirthdayClosure(seed, viewingKeys, walletBirthday)
    }

    var startRetryClosure: ((Bool) async throws -> Void)! = nil
    func start(retry: Bool) async throws {
        try await startRetryClosure(retry)
    }

    var stopClosure: (() async -> Void)! = nil
    func stop() async {
        await stopClosure()
    }

    var getSaplingAddressAccountIndexClosure: ((Int) async -> SaplingAddress?)! = nil
    func getSaplingAddress(accountIndex: Int) async -> SaplingAddress? {
        return await getSaplingAddressAccountIndexClosure(accountIndex)
    }

    var getUnifiedAddressAccountIndexClosure: ((Int) async -> UnifiedAddress?)! = nil
    func getUnifiedAddress(accountIndex: Int) async -> UnifiedAddress? {
        return await getUnifiedAddressAccountIndexClosure(accountIndex)
    }

    var getTransparentAddressAccountIndexClosure: ((Int) async -> TransparentAddress?)! = nil
    func getTransparentAddress(accountIndex: Int) async -> TransparentAddress? {
        return await getTransparentAddressAccountIndexClosure(accountIndex)
    }

    var sendToAddressSpendingKeyZatoshiToAddressMemoClosure: (
        (UnifiedSpendingKey, Zatoshi, Recipient, Memo?) async throws -> PendingTransactionEntity
    )! = nil
    func sendToAddress(spendingKey: UnifiedSpendingKey, zatoshi: Zatoshi, toAddress: Recipient, memo: Memo?) async throws -> PendingTransactionEntity {
        return try await sendToAddressSpendingKeyZatoshiToAddressMemoClosure(spendingKey, zatoshi, toAddress, memo)
    }

    var shieldFundsSpendingKeyMemoShieldingThresholdClosure: ((UnifiedSpendingKey, Memo, Zatoshi) async throws -> PendingTransactionEntity)! = nil
    func shieldFunds(spendingKey: UnifiedSpendingKey, memo: Memo, shieldingThreshold: Zatoshi) async throws -> PendingTransactionEntity {
        return try await shieldFundsSpendingKeyMemoShieldingThresholdClosure(spendingKey, memo, shieldingThreshold)
    }

    var cancelSpendTransactionClosure: ((PendingTransactionEntity) async -> Bool)! = nil
    func cancelSpend(transaction: PendingTransactionEntity) async -> Bool {
        return await cancelSpendTransactionClosure(transaction)
    }

    var underlyingPendingTransactions: [PendingTransactionEntity]! = nil
    var pendingTransactions: [PendingTransactionEntity] {
        get async { underlyingPendingTransactions }
    }

    var underlyingClearedTransactions: [ZcashTransaction.Overview]! = nil
    var clearedTransactions: [ZcashTransaction.Overview] {
        get async { underlyingClearedTransactions }
    }

    var underlyingSentTransactions: [ZcashTransaction.Sent]! = nil
    var sentTransactions: [ZcashTransaction.Sent] {
        get async { underlyingSentTransactions }
    }

    var underlyingReceivedTransactions: [ZcashTransaction.Received]! = nil
    var receivedTransactions: [ZcashTransaction.Received] {
        get async { underlyingReceivedTransactions }
    }

    var paginatedTransactionsOfKindClosure: ((TransactionKind) -> PaginatedTransactionRepository)! = nil
    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository {
        return paginatedTransactionsOfKindClosure(kind)
    }

    var getMemosForTransactionClosure: ((ZcashTransaction.Overview) async throws -> [Memo])! = nil
    func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        return try await getMemosForTransactionClosure(transaction)
    }

    var getMemosForReceivedTransactionClosure: ((ZcashTransaction.Received) async throws -> [Memo])! = nil
    func getMemos(for receivedTransaction: ZcashTransaction.Received) async throws -> [Memo] {
        return try await getMemosForReceivedTransactionClosure(receivedTransaction)
    }

    var getMemosForSentTransactionClosure: ((ZcashTransaction.Sent) async throws -> [Memo])! = nil
    func getMemos(for sentTransaction: ZcashTransaction.Sent) async throws -> [Memo] {
        return try await getMemosForSentTransactionClosure(sentTransaction)
    }

    var getRecipientsForClearedTransactionClosure: ((ZcashTransaction.Overview) async -> [TransactionRecipient])! = nil
    func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient] {
        return await getRecipientsForClearedTransactionClosure(transaction)
    }

    var getRecipientsForSentTransactionClosure: ((ZcashTransaction.Sent) async -> [TransactionRecipient])! = nil
    func getRecipients(for transaction: ZcashTransaction.Sent) async -> [TransactionRecipient] {
        return await getRecipientsForSentTransactionClosure(transaction)
    }

    var allConfirmedTransactionsFromTransactionClosure: ((ZcashTransaction.Overview, Int) async throws -> [ZcashTransaction.Overview])! = nil
    func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview] {
        return try await allConfirmedTransactionsFromTransactionClosure(transaction, limit)
    }

    var latestHeightClosure: (() async throws -> BlockHeight)! = nil
    func latestHeight() async throws -> BlockHeight {
        return try await latestHeightClosure()
    }

    var refreshUTXOsAddressFromHeightClosure: ((TransparentAddress, BlockHeight) async throws -> RefreshedUTXOs)! = nil
    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        return try await refreshUTXOsAddressFromHeightClosure(address, height)
    }

    var getTransparentBalanceAccountIndexClosure: ((Int) async throws -> WalletBalance)! = nil
    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance {
        return try await getTransparentBalanceAccountIndexClosure(accountIndex)
    }

    var getShieldedBalanceAccountIndexDeprecatedClosure: ((Int) -> Int64)! = nil
    func getShieldedBalance(accountIndex: Int) -> Int64 {
        return getShieldedBalanceAccountIndexDeprecatedClosure(accountIndex)
    }

    var getShieldedBalanceAccountIndexClosure: ((Int) -> Zatoshi)! = nil
    func getShieldedBalance(accountIndex: Int) -> Zatoshi {
        return getShieldedBalanceAccountIndexClosure(accountIndex)
    }

    var getShieldedVerifiedBalanceAccountIndexDeprecatedClosure: ((Int) -> Int64)! = nil
    func getShieldedVerifiedBalance(accountIndex: Int) -> Int64 {
        return getShieldedVerifiedBalanceAccountIndexDeprecatedClosure(accountIndex)
    }

    var getShieldedVerifiedBalanceAccountIndexClosure: ((Int) -> Zatoshi)! = nil
    func getShieldedVerifiedBalance(accountIndex: Int) -> Zatoshi {
        return getShieldedVerifiedBalanceAccountIndexClosure(accountIndex)
    }

    var rewindPolicyClosure: ((RewindPolicy) -> AnyPublisher<Void, Error>)! = nil
    func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error> {
        return rewindPolicyClosure(policy)
    }

    var wipeClosure: (() -> AnyPublisher<Void, Error>)! = nil
    func wipe() -> AnyPublisher<Void, Error> {
        return wipeClosure()
    }
}
