//
//  TransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

typealias TransactionEncoderResultBlock = (_ result: Result<EncodedTransaction, Error>) -> Void

public enum TransactionEncoderError: Error {
    case notFound(txId: Data)
    case notEncoded(txId: Data)
    case missingParams
    case spendingKeyWrongNetwork
    case couldNotExpand(txId: Data)
    case submitError(code: Int, message: String)
}

protocol TransactionEncoder {
    /// Creates a proposal for transferring funds to the given recipient.
    ///
    /// - Parameter accountIndex: the account from which to transfer funds.
    /// - Parameter recipient: string containing the recipient's address.
    /// - Parameter amount: the amount to send in Zatoshi.
    /// - Parameter memoBytes: an optional memo to include as part of the proposal's transactions. Use `nil` when sending to transparent receivers otherwise the function will throw an error.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func proposeTransfer(
        accountIndex: Int,
        recipient: String,
        amount: Zatoshi,
        memoBytes: MemoBytes?
    ) async throws -> Proposal

    /// Creates a proposal for shielding any transparent funds received by the given account.
    ///
    /// - Parameter accountIndex: the account for which to shield funds.
    /// - Parameter shieldingThreshold: the minimum transparent balance required before a proposal will be created.
    /// - Parameter memoBytes: an optional memo to include as part of the proposal's transactions.
    /// - Parameter transparentReceiver: a specific transparent receiver within the account
    ///             that should be the source of transparent funds. Default is `nil` which
    ///             will select whichever of the account's transparent receivers has funds
    ///             to shield.
    ///
    /// Returns the proposal, or `nil` if the transparent balance that would be shielded
    /// is zero or below `shieldingThreshold`.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func proposeShielding(
        accountIndex: Int,
        shieldingThreshold: Zatoshi,
        memoBytes: MemoBytes?,
        transparentReceiver: String?
    ) async throws -> Proposal?

    /// Creates the transactions in the given proposal.
    ///
    /// - Parameter proposal: the proposal for which to create transactions.
    /// - Parameter spendingKey: the `UnifiedSpendingKey` associated with the account for which the proposal was created.
    /// - Throws:
    ///     - `walletTransEncoderCreateTransactionMissingSaplingParams` if the sapling parameters aren't downloaded.
    ///     - Some `ZcashError.rust*` if the creation of transaction(s) fails.
    ///
    /// If `prepare()` hasn't already been called since creation of the synchronizer instance or since the last wipe then this method throws
    /// `SynchronizerErrors.notPrepared`.
    func createProposedTransactions(
        proposal: Proposal,
        spendingKey: UnifiedSpendingKey
    ) async throws -> [ZcashTransaction.Overview]

    /// submits a transaction to the Zcash peer-to-peer network.
    /// - Parameter transaction: a transaction overview
    func submit(transaction: EncodedTransaction) async throws

    func closeDBConnection()
}
