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

extension ZcashRustBackendWeldingMock {
    static func makeDefaultMock(
        rustBackend: ZcashRustBackendWelding,
        consensusBranchID: Int32? = nil,
        mockValidateCombinedChainSuccessRate: Float? = nil,
        mockValidateCombinedChainFailAfterAttempts: Int? = nil,
        mockValidateCombinedChainKeepFailing: Bool = false,
        mockValidateCombinedChainFailureError: RustWeldingError = .chainValidationFailed(message: nil)
    ) async -> ZcashRustBackendWeldingMock {
        let mock = ZcashRustBackendWeldingMock()
        await mock.setLatestCachedBlockHeightReturnValue(.empty())
        await mock.setInitBlockMetadataDbClosure() { }
        await mock.setWriteBlocksMetadataBlocksClosure() { _ in }
        await mock.setInitAccountsTableUfvksClosure() { _ in }
        await mock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await mock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        ZcashRustBackendWeldingMock.getAddressMetadataReturnValue = nil
        await mock.setGetTransparentBalanceAccountReturnValue(0)
        await mock.setGetVerifiedBalanceAccountReturnValue(0)
        await mock.setListTransparentReceiversAccountReturnValue([])
        await mock.setDeriveUnifiedFullViewingKeyFromThrowableError(KeyDerivationErrors.unableToDerive)
        await mock.setDeriveUnifiedSpendingKeyFromAccountIndexThrowableError(KeyDerivationErrors.unableToDerive)
        await mock.setGetCurrentAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        await mock.setGetNextAvailableAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        ZcashRustBackendWeldingMock.getSaplingReceiverForThrowableError = KeyDerivationErrors.unableToDerive
        ZcashRustBackendWeldingMock.getTransparentReceiverForThrowableError = KeyDerivationErrors.unableToDerive
        await mock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        ZcashRustBackendWeldingMock.receiverTypecodesOnUnifiedAddressThrowableError = KeyDerivationErrors.receiverNotFound
        await mock.setCreateAccountSeedThrowableError(KeyDerivationErrors.unableToDerive)
        await mock.setGetReceivedMemoIdNoteReturnValue(nil)
        await mock.setGetSentMemoIdNoteReturnValue(nil)
        await mock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await mock.setInitDataDbSeedReturnValue(.seedRequired)
        ZcashRustBackendWeldingMock.isValidSaplingAddressNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidUnifiedAddressNetworkTypeReturnValue = false
        await mock.setGetNearestRewindHeightHeightReturnValue(-1)
        await mock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { _, _, _, _ in }
        await mock.setPutUnspentTransparentOutputTxidIndexScriptValueHeightClosure() { _, _, _, _, _ in }
        await mock.setCreateToAddressUskToValueMemoReturnValue(-1)
        ZcashRustBackendWeldingMock.isValidSaplingExtendedFullViewingKeyNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidUnifiedFullViewingKeyNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidSaplingAddressNetworkTypeReturnValue = true
        ZcashRustBackendWeldingMock.isValidTransparentAddressNetworkTypeReturnValue = true
        await mock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await mock.setDecryptAndStoreTransactionTxBytesMinedHeightThrowableError(RustWeldingError.genericError(message: "mock fail"))

        await mock.setConsensusBranchIdForHeightClosure() { height in
            if let consensusBranchID {
                return consensusBranchID
            } else {
                return try await rustBackend.consensusBranchIdFor(height: height)
            }
        }

        await mock.setInitDataDbSeedClosure() { seed in
            return try await rustBackend.initDataDb(seed: seed)
        }

        await mock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { height, hash, time, saplingTree in
            try await rustBackend.initBlocksTable(
                height: height,
                hash: hash,
                time: time,
                saplingTree: saplingTree
            )
        }

        await mock.setGetBalanceAccountClosure() { account in
            return try await rustBackend.getBalance(account: account)
        }

        await mock.setGetVerifiedBalanceAccountClosure() { account in
            return try await rustBackend.getVerifiedBalance(account: account)
        }

        await mock.setValidateCombinedChainLimitClosure() { limit in
            var mockValidateCombinedChainFailAfterAttempts = mockValidateCombinedChainFailAfterAttempts
            if let rate = mockValidateCombinedChainSuccessRate {
                if Self.shouldSucceed(successRate: rate) {
                    return try await rustBackend.validateCombinedChain(limit: limit)
                } else {
                    throw mockValidateCombinedChainFailureError
                }
            } else if let attempts = mockValidateCombinedChainFailAfterAttempts {
                mockValidateCombinedChainFailAfterAttempts = attempts - 1
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

        await mock.setRewindToHeightHeightClosure() { height in
            try await rustBackend.rewindToHeight(height: height)
        }

        await mock.setRewindCacheToHeightHeightClosure() { _ in }

        await mock.setScanBlocksLimitClosure() { limit in
            try await rustBackend.scanBlocks(limit: limit)
        }

        return mock
    }

    static func shouldSucceed(successRate: Float) -> Bool {
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
