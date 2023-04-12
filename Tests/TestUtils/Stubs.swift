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
    let rustBackendMock: ZcashRustBackendWeldingMock
    var mockValidateCombinedChainFailAfterAttempts: Int?

    init(
        rustBackend: ZcashRustBackendWelding,
        consensusBranchID: Int32? = nil,
        mockValidateCombinedChainSuccessRate: Float? = nil,
        mockValidateCombinedChainFailAfterAttempts: Int? = nil,
        mockValidateCombinedChainKeepFailing: Bool = false,
        mockValidateCombinedChainFailureError: RustWeldingError = .chainValidationFailed(message: nil)
    ) async {
        self.mockValidateCombinedChainFailAfterAttempts = mockValidateCombinedChainFailAfterAttempts
        self.rustBackendMock = ZcashRustBackendWeldingMock(
            consensusBranchIdForHeightClosure: { height in
                if let consensusBranchID {
                    return consensusBranchID
                } else {
                    return try rustBackend.consensusBranchIdFor(height: height)
                }
            }
        )
        await setupDefaultMock(
            rustBackend: rustBackend,
            mockValidateCombinedChainSuccessRate: mockValidateCombinedChainSuccessRate,
            mockValidateCombinedChainKeepFailing: mockValidateCombinedChainKeepFailing,
            mockValidateCombinedChainFailureError: mockValidateCombinedChainFailureError
        )
    }

    private func setupDefaultMock(
        rustBackend: ZcashRustBackendWelding,
        mockValidateCombinedChainSuccessRate: Float? = nil,
        mockValidateCombinedChainKeepFailing: Bool = false,
        mockValidateCombinedChainFailureError: RustWeldingError = .chainValidationFailed(message: nil)
    ) async {
        await rustBackendMock.setLatestCachedBlockHeightReturnValue(.empty())
        await rustBackendMock.setInitBlockMetadataDbClosure() { }
        await rustBackendMock.setWriteBlocksMetadataBlocksClosure() { _ in }
        await rustBackendMock.setInitAccountsTableUfvksClosure() { _ in }
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        await rustBackendMock.setGetTransparentBalanceAccountReturnValue(0)
        await rustBackendMock.setGetVerifiedBalanceAccountReturnValue(0)
        await rustBackendMock.setListTransparentReceiversAccountReturnValue([])
        await rustBackendMock.setGetCurrentAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setGetNextAvailableAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        await rustBackendMock.setCreateAccountSeedThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setGetReceivedMemoIdNoteReturnValue(nil)
        await rustBackendMock.setGetSentMemoIdNoteReturnValue(nil)
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setInitDataDbSeedReturnValue(.seedRequired)
        await rustBackendMock.setGetNearestRewindHeightHeightReturnValue(-1)
        await rustBackendMock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { _, _, _, _ in }
        await rustBackendMock.setPutUnspentTransparentOutputTxidIndexScriptValueHeightClosure() { _, _, _, _, _ in }
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setDecryptAndStoreTransactionTxBytesMinedHeightThrowableError(RustWeldingError.genericError(message: "mock fail"))

        await rustBackendMock.setInitDataDbSeedClosure() { seed in
            return try await rustBackend.initDataDb(seed: seed)
        }

        await rustBackendMock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { height, hash, time, saplingTree in
            try await rustBackend.initBlocksTable(
                height: height,
                hash: hash,
                time: time,
                saplingTree: saplingTree
            )
        }

        await rustBackendMock.setGetBalanceAccountClosure() { account in
            return try await rustBackend.getBalance(account: account)
        }

        await rustBackendMock.setGetVerifiedBalanceAccountClosure() { account in
            return try await rustBackend.getVerifiedBalance(account: account)
        }

        await rustBackendMock.setValidateCombinedChainLimitClosure() { [weak self] limit in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            if let rate = mockValidateCombinedChainSuccessRate {
                if Self.shouldSucceed(successRate: rate) {
                    return try await rustBackend.validateCombinedChain(limit: limit)
                } else {
                    throw mockValidateCombinedChainFailureError
                }
            } else if let attempts = self.mockValidateCombinedChainFailAfterAttempts {
                self.mockValidateCombinedChainFailAfterAttempts = attempts - 1
                if attempts > 0 {
                    return try await rustBackend.validateCombinedChain(limit: limit)
                } else {
                    if attempts == 0 {
                        throw mockValidateCombinedChainFailureError
                    } else if attempts < 0 && mockValidateCombinedChainKeepFailing {
                        throw mockValidateCombinedChainFailureError
                    } else {
                        return try await rustBackend.validateCombinedChain(limit: limit)
                    }
                }
            } else {
                return try await rustBackend.validateCombinedChain(limit: limit)
            }
        }

        await rustBackendMock.setRewindToHeightHeightClosure() { height in
            try await rustBackend.rewindToHeight(height: height)
        }

        await rustBackendMock.setRewindCacheToHeightHeightClosure() { _ in }

        await rustBackendMock.setScanBlocksLimitClosure() { limit in
            try await rustBackend.scanBlocks(limit: limit)
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
