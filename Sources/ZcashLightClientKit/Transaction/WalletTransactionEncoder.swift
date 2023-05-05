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

    func submit(
        transaction: EncodedTransaction
    ) async throws {
        let response = try await self.lightWalletService.submit(spendTransaction: transaction.raw)

        guard response.errorCode >= 0 else {
            throw TransactionEncoderError.submitError(code: Int(response.errorCode) , message: response.errorMessage)
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
            throw TransactionEncoderError.notEncoded(transactionId: self.id)
        }

        return EncodedTransaction(transactionId: self.rawID, raw: raw)
    }
}
