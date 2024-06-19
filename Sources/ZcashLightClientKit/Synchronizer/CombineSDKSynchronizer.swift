//
//  CombineSDKSynchronizer.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

/// This is a super thin layer that implements the `CombineSynchronizer` protocol and translates the async API defined in `Synchronizer` to
/// Combine-based API. And it doesn't do anything else. It doesn't keep any state. It's here so each client can choose the API that suits its case the
/// best. And usage of this can be combined with usage of `ClosureSDKSynchronizer`. So devs can really choose the best SDK API for each part of the
/// client app.
///
/// If you are looking for documentation for a specific method or property look for it in the `Synchronizer` protocol.
public struct CombineSDKSynchronizer {
    private let synchronizer: Synchronizer

    public init(synchronizer: Synchronizer) {
        self.synchronizer = synchronizer
    }
}

extension CombineSDKSynchronizer: CombineSynchronizer {
    public var alias: ZcashSynchronizerAlias { synchronizer.alias }

    public var latestState: SynchronizerState { synchronizer.latestState }
    public var connectionState: ConnectionState { synchronizer.connectionState }

    public var stateStream: AnyPublisher<SynchronizerState, Never> { synchronizer.stateStream }
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { synchronizer.eventStream }

    public func prepare(
        with seed: [UInt8]?,
        walletBirthday: BlockHeight,
        for walletMode: WalletInitMode
    ) -> SinglePublisher<Initializer.InitializationResult, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            return try await self.synchronizer.prepare(with: seed, walletBirthday: walletBirthday, for: walletMode)
        }
    }

    public func start(retry: Bool) -> CompletablePublisher<Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.start(retry: retry)
        }
    }

    public func stop() {
        synchronizer.stop()
    }

    public func getSaplingAddress(accountIndex: Int) -> SinglePublisher<SaplingAddress, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getSaplingAddress(accountIndex: accountIndex)
        }
    }

    public func getUnifiedAddress(accountIndex: Int) -> SinglePublisher<UnifiedAddress, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getUnifiedAddress(accountIndex: accountIndex)
        }
    }

    public func getTransparentAddress(accountIndex: Int) -> SinglePublisher<TransparentAddress, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getTransparentAddress(accountIndex: accountIndex)
        }
    }

    public func proposeTransfer(
        accountIndex: Int,
        recipient: Recipient,
        amount: Zatoshi,
        memo: Memo?
    ) -> SinglePublisher<Proposal, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.proposeTransfer(accountIndex: accountIndex, recipient: recipient, amount: amount, memo: memo)
        }
    }

    public func proposefulfillingPaymentURI(
        _ uri: String,
        accountIndex: Int
    ) -> SinglePublisher<Proposal, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.proposefulfillingPaymentURI(
                uri,
                accountIndex: accountIndex
            )
        }
    }

    public func proposeShielding(
        accountIndex: Int,
        shieldingThreshold: Zatoshi,
        memo: Memo,
        transparentReceiver: TransparentAddress? = nil
    ) -> SinglePublisher<Proposal?, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.proposeShielding(
                accountIndex: accountIndex,
                shieldingThreshold: shieldingThreshold,
                memo: memo,
                transparentReceiver: transparentReceiver
            )
        }
    }

    public func createProposedTransactions(
        proposal: Proposal,
        spendingKey: UnifiedSpendingKey
    ) -> SinglePublisher<AsyncThrowingStream<TransactionSubmitResult, Error>, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.createProposedTransactions(proposal: proposal, spendingKey: spendingKey)
        }
    }

    @available(*, deprecated, message: "Upcoming SDK 2.1 will create multiple transactions at once for some recipients.")
    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) -> SinglePublisher<ZcashTransaction.Overview, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        }
    }

    @available(*, deprecated, message: "Upcoming SDK 2.1 will create multiple transactions at once for some recipients.")
    public func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) -> SinglePublisher<ZcashTransaction.Overview, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.shieldFunds(spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        }
    }

    public var allTransactions: SinglePublisher<[ZcashTransaction.Overview], Never> {
        AsyncToCombineGateway.executeAction() {
            await self.synchronizer.transactions
        }
    }

    public var sentTransactions: SinglePublisher<[ZcashTransaction.Overview], Never> {
        AsyncToCombineGateway.executeAction() {
            await self.synchronizer.sentTransactions
        }
    }

    public var receivedTransactions: SinglePublisher<[ZcashTransaction.Overview], Never> {
        AsyncToCombineGateway.executeAction() {
            await self.synchronizer.receivedTransactions
        }
    }
    
    public func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository { synchronizer.paginatedTransactions(of: kind) }

    public func getMemos(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[Memo], Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getMemos(for: transaction)
        }
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[TransactionRecipient], Never> {
        AsyncToCombineGateway.executeAction() {
            await self.synchronizer.getRecipients(for: transaction)
        }
    }

    public func allTransactions(from transaction: ZcashTransaction.Overview, limit: Int) -> SinglePublisher<[ZcashTransaction.Overview], Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.allTransactions(from: transaction, limit: limit)
        }
    }

    public func latestHeight() -> SinglePublisher<BlockHeight, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.latestHeight()
        }
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) -> SinglePublisher<RefreshedUTXOs, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.refreshUTXOs(address: address, from: height)
        }
    }

    public func getAccountBalance(accountIndex: Int) -> SinglePublisher<AccountBalance?, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getAccountBalance(accountIndex: accountIndex)
        }
    }

    public func getExchangeRateUSD() -> SinglePublisher<NSDecimalNumber, Error> {
        AsyncToCombineGateway.executeThrowingAction() {
            try await self.synchronizer.getExchangeRateUSD()
        }
    }

    public func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error> { synchronizer.rewind(policy) }
    public func wipe() -> CompletablePublisher<Error> { synchronizer.wipe() }
}
