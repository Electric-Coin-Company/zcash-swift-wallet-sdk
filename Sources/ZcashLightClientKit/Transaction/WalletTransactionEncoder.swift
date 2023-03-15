//
//  WalletTransactionEncoder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/20/19.
//

import Foundation

class WalletTransactionEncoder: TransactionEncoder {
    var rustBackend: ZcashRustBackendWelding.Type
    var repository: TransactionRepository

    private var outputParamsURL: URL
    private var spendParamsURL: URL
    private var dataDbURL: URL
    private var fsBlockDbRoot: URL
    private var networkType: NetworkType
    
    init(
        rust: ZcashRustBackendWelding.Type,
        dataDb: URL,
        fsBlockDbRoot: URL,
        repository: TransactionRepository,
        outputParams: URL,
        spendParams: URL,
        networkType: NetworkType
    ) {
        self.rustBackend = rust
        self.dataDbURL = dataDb
        self.fsBlockDbRoot = fsBlockDbRoot
        self.repository = repository
        self.outputParamsURL = outputParams
        self.spendParamsURL = spendParams
        self.networkType = networkType
    }
    
    convenience init(initializer: Initializer) {
        self.init(
            rust: initializer.rustBackend,
            dataDb: initializer.dataDbURL,
            fsBlockDbRoot: initializer.fsBlockDbRoot,
            repository: initializer.transactionRepository,
            outputParams: initializer.outputParamsURL,
            spendParams: initializer.spendParamsURL,
            networkType: initializer.network.networkType
        )
    }
    
    func createTransaction(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview {
        let txId = try createSpend(
            spendingKey: spendingKey,
            zatoshi: zatoshi,
            to: address,
            memoBytes: memoBytes,
            from: accountIndex
        )

        do {
            LoggerProxy.debug("transaction id: \(txId)")
            return try repository.find(id: txId)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }
    
    func createSpend(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        to address: String,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.outputParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
                
        let txId = rustBackend.createToAddress(
            dbData: self.dataDbURL,
            usk: spendingKey,
            to: address,
            value: zatoshi.amount,
            memo: memoBytes,
            spendParamsPath: self.spendParamsURL.path,
            outputParamsPath: self.outputParamsURL.path,
            networkType: networkType
        )
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return Int(txId)
    }
    
    func createShieldingTransaction(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        memoBytes: MemoBytes?,
        from accountIndex: Int
    ) async throws -> ZcashTransaction.Overview {
        let txId = try createShieldingSpend(
            spendingKey: spendingKey,
            shieldingThreshold: shieldingThreshold,
            memo: memoBytes,
            accountIndex: accountIndex
        )
        
        do {
            LoggerProxy.debug("transaction id: \(txId)")
            return try repository.find(id: txId)
        } catch {
            throw TransactionEncoderError.notFound(transactionId: txId)
        }
    }

    func createShieldingSpend(
        spendingKey: UnifiedSpendingKey,
        shieldingThreshold: Zatoshi,
        memo: MemoBytes?,
        accountIndex: Int
    ) throws -> Int {
        guard ensureParams(spend: self.spendParamsURL, output: self.outputParamsURL) else {
            throw TransactionEncoderError.missingParams
        }
        
        let txId = rustBackend.shieldFunds(
            dbData: self.dataDbURL,
            usk: spendingKey,
            memo: memo,
            shieldingThreshold: shieldingThreshold,
            spendParamsPath: self.spendParamsURL.path,
            outputParamsPath: self.outputParamsURL.path,
            networkType: networkType
        )
        
        guard txId > 0 else {
            throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "create spend failed")
        }
        
        return Int(txId)
    }
    
    func ensureParams(spend: URL, output: URL) -> Bool {
        let readableSpend = FileManager.default.isReadableFile(atPath: spend.path)
        let readableOutput = FileManager.default.isReadableFile(atPath: output.path)
        
        // TODO: [#713] change this to something that makes sense, https://github.com/zcash/ZcashLightClientKit/issues/713
        return readableSpend && readableOutput
    }
}
