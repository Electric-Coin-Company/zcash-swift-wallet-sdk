//
//  Stubs.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import SwiftProtobuf
@testable import ZcashLightClientKit

class AwfulLightWalletService: MockLightWalletService {
    override func latestBlockHeight() async throws -> BlockHeight {
        throw LightWalletServiceError.criticalError
    }

    override func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: LightWalletServiceError.invalidBlock) }
    }

    /// Submits a raw transaction over lightwalletd.
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        throw LightWalletServiceError.invalidBlock
    }
}

extension LightWalletServiceMockResponse: Error { }

class SlightlyBadLightWalletService: MockLightWalletService {
    /// Submits a raw transaction over lightwalletd.
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        throw LightWalletServiceMockResponse.error
    }
}

extension LightWalletServiceMockResponse {
    static var error: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(
            errorCode: -100,
            errorMessage: "Ohhh this is bad, really bad, you lost all your internet money",
            unknownFields: UnknownStorage()
        )
    }

    static var success: LightWalletServiceMockResponse {
        LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())
    }
}

class RustBackendMockHelper {
    let rustBackend: ZcashRustBackendWelding
    let rustBackendMock: ZcashRustBackendWeldingMock
    let consensusBranchID: Int32?
    let mockValidateCombinedChainSuccessRate: Float?
    var mockValidateCombinedChainFailAfterAttempts: Int?
    let mockValidateCombinedChainKeepFailing: Bool
    let mockValidateCombinedChainFailureError: RustWeldingError

    init(
        rustBackend: ZcashRustBackendWelding,
        consensusBranchID: Int32? = nil,
        mockValidateCombinedChainSuccessRate: Float? = nil,
        mockValidateCombinedChainFailAfterAttempts: Int? = nil,
        mockValidateCombinedChainKeepFailing: Bool = false,
        mockValidateCombinedChainFailureError: RustWeldingError = .chainValidationFailed(message: nil)
    ) {
        self.rustBackend = rustBackend
        self.consensusBranchID = consensusBranchID
        self.mockValidateCombinedChainSuccessRate = mockValidateCombinedChainSuccessRate
        self.mockValidateCombinedChainFailAfterAttempts = mockValidateCombinedChainFailAfterAttempts
        self.mockValidateCombinedChainKeepFailing = mockValidateCombinedChainKeepFailing
        self.mockValidateCombinedChainFailureError = mockValidateCombinedChainFailureError
        self.rustBackendMock = ZcashRustBackendWeldingMock()
        setupDefaultMock()
    }

    private func setupDefaultMock() {
        rustBackendMock.latestCachedBlockHeightReturnValue = .empty()
        rustBackendMock.initBlockMetadataDbClosure = { }
        rustBackendMock.writeBlocksMetadataBlocksClosure = { _ in }
        rustBackendMock.initAccountsTableUfvksClosure = { _ in }
        rustBackendMock.createToAddressUskToValueMemoReturnValue = -1
        rustBackendMock.shieldFundsUskMemoShieldingThresholdReturnValue = -1
        rustBackendMock.getTransparentBalanceAccountReturnValue = 0
        rustBackendMock.getVerifiedBalanceAccountReturnValue = 0
        rustBackendMock.listTransparentReceiversAccountReturnValue = []
        rustBackendMock.getCurrentAddressAccountThrowableError = KeyDerivationErrors.unableToDerive
        rustBackendMock.getNextAvailableAddressAccountThrowableError = KeyDerivationErrors.unableToDerive
        rustBackendMock.shieldFundsUskMemoShieldingThresholdReturnValue = -1
        rustBackendMock.createAccountSeedThrowableError = KeyDerivationErrors.unableToDerive
        rustBackendMock.getReceivedMemoIdNoteReturnValue = nil
        rustBackendMock.getSentMemoIdNoteReturnValue = nil
        rustBackendMock.createToAddressUskToValueMemoReturnValue = -1
        rustBackendMock.initDataDbSeedReturnValue = .seedRequired
        rustBackendMock.getNearestRewindHeightHeightReturnValue = -1
        rustBackendMock.initBlocksTableHeightHashTimeSaplingTreeClosure = { _, _, _, _ in }
        rustBackendMock.putUnspentTransparentOutputTxidIndexScriptValueHeightClosure = { _, _, _, _, _ in }
        rustBackendMock.createToAddressUskToValueMemoReturnValue = -1
        rustBackendMock.createToAddressUskToValueMemoReturnValue = -1
        rustBackendMock.decryptAndStoreTransactionTxBytesMinedHeightThrowableError = RustWeldingError.genericError(message: "mock fail")

        rustBackendMock.consensusBranchIdForHeightClosure = { [weak self] height in
            guard let self else { return -1 }
            if let consensusBranchID = self.consensusBranchID {
                return consensusBranchID
            } else {
                return try self.rustBackend.consensusBranchIdFor(height: height)
            }
        }

        rustBackendMock.initDataDbSeedClosure = { [weak self] seed in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try self.rustBackend.initDataDb(seed: seed)
        }

        rustBackendMock.initBlocksTableHeightHashTimeSaplingTreeClosure = { [weak self] height, hash, time, saplingTree in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try self.rustBackend.initBlocksTable(
                height: height,
                hash: hash,
                time: time,
                saplingTree: saplingTree
            )
        }

        rustBackendMock.getBalanceAccountClosure = { [weak self] account in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try self.rustBackend.getBalance(account: account)
        }

        rustBackendMock.getVerifiedBalanceAccountClosure = { [weak self] account in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try self.rustBackend.getVerifiedBalance(account: account)
        }

        rustBackendMock.validateCombinedChainLimitClosure = { [weak self] limit in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            if let rate = self.mockValidateCombinedChainSuccessRate {
                if Self.shouldSucceed(successRate: rate) {
                    return try self.rustBackend.validateCombinedChain(limit: limit)
                } else {
                    throw self.mockValidateCombinedChainFailureError
                }
            } else if let attempts = self.mockValidateCombinedChainFailAfterAttempts {
                self.mockValidateCombinedChainFailAfterAttempts = attempts - 1
                if attempts > 0 {
                    return try self.rustBackend.validateCombinedChain(limit: limit)
                } else {
                    if attempts == 0 {
                        throw self.mockValidateCombinedChainFailureError
                    } else if attempts < 0 && self.mockValidateCombinedChainKeepFailing {
                        throw self.mockValidateCombinedChainFailureError
                    } else {
                        return try self.rustBackend.validateCombinedChain(limit: limit)
                    }
                }
            } else {
                return try self.rustBackend.validateCombinedChain(limit: limit)
            }
        }

        rustBackendMock.rewindToHeightHeightClosure = { [weak self] height in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try self.rustBackend.rewindToHeight(height: height)
        }

        rustBackendMock.rewindCacheToHeightHeightClosure = { _ in }

        rustBackendMock.scanBlocksLimitClosure = { [weak self] limit in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try self.rustBackend.scanBlocks(limit: limit)
        }
    }

    private static func shouldSucceed(successRate: Float) -> Bool {
        let random = Float.random(in: 0.0...1.0)
        return random <= successRate
    }
}

extension SaplingParamsSourceURL {
    static var tests = SaplingParamsSourceURL(
        spendParamFileURL: Bundle.module.url(forResource: "sapling-spend", withExtension: "params")!,
        outputParamFileURL: Bundle.module.url(forResource: "sapling-output", withExtension: "params")!
    )
}

extension CompactBlockProcessor.Configuration {
    /// Standard configuration for most compact block processors
    static func standard(
        alias: ZcashSynchronizerAlias = .default,
        for network: ZcashNetwork,
        walletBirthday: BlockHeight
    ) -> CompactBlockProcessor.Configuration {
        let pathProvider = DefaultResourceProvider(network: network)
        return CompactBlockProcessor.Configuration(
            alias: alias,
            fsBlockCacheRoot: pathProvider.fsCacheURL,
            dataDb: pathProvider.dataDbURL,
            spendParamsURL: pathProvider.spendParamsURL,
            outputParamsURL: pathProvider.outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            walletBirthdayProvider: { walletBirthday },
            network: network
        )
    }
}
