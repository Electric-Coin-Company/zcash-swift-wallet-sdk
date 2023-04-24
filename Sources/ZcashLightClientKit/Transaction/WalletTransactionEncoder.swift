//
//  WalletTransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

class WalletTransactionEncoder: TransactionEncoder {
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
        repository: TransactionRepository,
        outputParams: URL,
        spendParams: URL,
        networkType: NetworkType,
        logger: Logger
    ) {
        self.rustBackend = rustBackend
        self.dataDbURL = dataDb
        self.fsBlockDbRoot = fsBlockDbRoot
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
            repository: initializer.transactionRepository,
            outputParams: initializer.outputParamsURL,
            spendParams: initializer.spendParamsURL,
            networkType: initializer.network.networkType,
            logger: initializer.logger
        )
    }
    
    func createTransaction(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview {
        let txId = try await createSpend(
            spendingKey: spendingKey,
            zatoshi: zatoshi,
            to: address,
            memoBytes: memoBytes,
            from: accountIndex
        )

        logger.debug("transaction id: \(txId)")
        return try await repository.find(id: txId)
    }
    
    func createSpend(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.outputParamsURL) else {
            throw ZcashError.walletTransEncoderCreateTransactionMissingSaplingParams
        }

        let txId = try await rustBackend.createToAddress(
            usk: spendingKey,
            to: address,
            value: zatoshi.amount,
            memo: memoBytes
        )

        return Int(txId)
    }
    
    func createShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview {
        let txId = try await createShieldingSpend(
            spendingKey: spendingKey,
            shieldingThreshold: shieldingThreshold,
            memo: memoBytes,
            accountIndex: accountIndex
        )
        
        logger.debug("transaction id: \(txId)")
        return try await repository.find(id: txId)
    }

    func createShieldingSpend(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        memo: MemoBytes?,
        accountIndex: Int
    ) async throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.outputParamsURL) else {
            throw ZcashError.walletTransEncoderShieldFundsMissingSaplingParams
        }
        
        let txId = try await rustBackend.shieldFunds(
            usk: spendingKey,
            memo: memo,
            shieldingThreshold: shieldingThreshold
        )
                
        return Int(txId)
    }
    
    func ensureParams(spend: URL, output: URL) -> Bool {
        let readableSpend = FileManager.default.isReadableFile(atPath: spend.path)
        let readableOutput = FileManager.default.isReadableFile(atPath: output.path)
        
        // TODO: [#713] change this to something that makes sense, https://github.com/zcash/ZcashLightClientKit/issues/713
        return readableSpend && readableOutput
    }
}
