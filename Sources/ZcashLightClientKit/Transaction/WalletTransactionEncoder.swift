//
//  WalletTransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

class WalletTransactionEncoder: TransactionEncoder {
    let lightWalletService: LightWalletService
    let rustBackend: ZcashRustBackendWelding
    let repository: TransactionRepository
    let logger: Logger

    private let outputParamsURL: URL
    private let spendParamsURL: URL
    private let dataDbURL: URL
    private let fsBlockDbRoot: URL
    private let networkType: NetworkType
    
    init(
        rustBackend: ZcashRustBackendWelding,
        dataDb: URL,
        fsBlockDbRoot: URL,
        service: LightWalletService,
        repository: TransactionRepository,
        outputParams: URL,
        spendParams: URL,
        networkType: NetworkType,
        logger: Logger
    ) {
        self.rustBackend = rustBackend
        self.dataDbURL = dataDb
        self.fsBlockDbRoot = fsBlockDbRoot
        self.lightWalletService = service
        self.repository = repository
        self.outputParamsURL = outputParams
        self.spendParamsURL = spendParams
        self.networkType = networkType
        self.logger = logger
    }
    
    convenience init(initializer: Initializer) {
        self.init(
            rustBackend: initializer.rustBackend,
            dataDb: initializer.dataDbURL,
            fsBlockDbRoot: initializer.fsBlockDbRoot,
            service: initializer.lightWalletService,
            repository: initializer.transactionRepository,
            outputParams: initializer.outputParamsURL,
            spendParams: initializer.spendParamsURL,
            networkType: initializer.network.networkType,
            logger: initializer.logger
        )
    }

    func proposeTransfer(
        accountIndex: Int,
        recipient: String,
        amount: Zatoshi,
        memoBytes: MemoBytes?
    ) async throws -> Proposal {
        let proposal = try await rustBackend.proposeTransfer(
            account: Int32(accountIndex),
            to: recipient,
            value: amount.amount,
            memo: memoBytes
        )

        return Proposal(inner: proposal)
    }

    func proposeShielding(
        accountIndex: Int,
        shieldingThreshold: Zatoshi,
        memoBytes: MemoBytes?,
        transparentReceiver: String? = nil
    ) async throws -> Proposal? {
        guard let proposal = try await rustBackend.proposeShielding(
            account: Int32(accountIndex),
            memo: memoBytes,
            shieldingThreshold: shieldingThreshold,
            transparentReceiver: transparentReceiver
        ) else { return nil }

        return Proposal(inner: proposal)
    }

    func createProposedTransactions(
        proposal: Proposal,
        spendingKey: UnifiedSpendingKey
    ) async throws -> [ZcashTransaction.Overview] {
        guard ensureParams(spend: self.spendParamsURL, output: self.outputParamsURL) else {
            throw ZcashError.walletTransEncoderCreateTransactionMissingSaplingParams
        }

        let txId = try await rustBackend.createProposedTransaction(
            proposal: proposal.inner,
            usk: spendingKey
        )

        logger.debug("transaction id: \(txId)")
        return [try await repository.find(rawID: txId)]
    }

    func submit(
        transaction: EncodedTransaction
    ) async throws {
        let response = try await self.lightWalletService.submit(spendTransaction: transaction.raw)

        guard response.errorCode >= 0 else {
            throw TransactionEncoderError.submitError(code: Int(response.errorCode), message: response.errorMessage)
        }
    }

    func ensureParams(spend: URL, output: URL) -> Bool {
        let readableSpend = FileManager.default.isReadableFile(atPath: spend.path)
        let readableOutput = FileManager.default.isReadableFile(atPath: output.path)
        
        // TODO: [#713] change this to something that makes sense, https://github.com/zcash/ZcashLightClientKit/issues/713
        return readableSpend && readableOutput
    }

    func closeDBConnection() {
        self.repository.closeDBConnection()
    }
}

extension ZcashTransaction.Overview {
    func encodedTransaction() throws -> EncodedTransaction {
        guard let raw else {
            throw TransactionEncoderError.notEncoded(txId: self.rawID)
        }

        return EncodedTransaction(transactionId: self.rawID, raw: raw)
    }
}
