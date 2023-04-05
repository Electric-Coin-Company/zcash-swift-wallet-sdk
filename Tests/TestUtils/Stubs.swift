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
    ) async {
        self.rustBackend = rustBackend
        self.consensusBranchID = consensusBranchID
        self.mockValidateCombinedChainSuccessRate = mockValidateCombinedChainSuccessRate
        self.mockValidateCombinedChainFailAfterAttempts = mockValidateCombinedChainFailAfterAttempts
        self.mockValidateCombinedChainKeepFailing = mockValidateCombinedChainKeepFailing
        self.mockValidateCombinedChainFailureError = mockValidateCombinedChainFailureError
        self.rustBackendMock = ZcashRustBackendWeldingMock()
        await setupDefaultMock()
    }

    private func setupDefaultMock() async {
        await rustBackendMock.setLatestCachedBlockHeightReturnValue(.empty())
        await rustBackendMock.setInitBlockMetadataDbClosure() { }
        await rustBackendMock.setWriteBlocksMetadataBlocksClosure() { _ in }
        await rustBackendMock.setInitAccountsTableUfvksClosure() { _ in }
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        ZcashRustBackendWeldingMock.getAddressMetadataReturnValue = nil
        await rustBackendMock.setGetTransparentBalanceAccountReturnValue(0)
        await rustBackendMock.setGetVerifiedBalanceAccountReturnValue(0)
        await rustBackendMock.setListTransparentReceiversAccountReturnValue([])
        await rustBackendMock.setDeriveUnifiedFullViewingKeyFromThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setDeriveUnifiedSpendingKeyFromAccountIndexThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setGetCurrentAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setGetNextAvailableAddressAccountThrowableError(KeyDerivationErrors.unableToDerive)
        ZcashRustBackendWeldingMock.getSaplingReceiverForThrowableError = KeyDerivationErrors.unableToDerive
        ZcashRustBackendWeldingMock.getTransparentReceiverForThrowableError = KeyDerivationErrors.unableToDerive
        await rustBackendMock.setShieldFundsUskMemoShieldingThresholdReturnValue(-1)
        ZcashRustBackendWeldingMock.receiverTypecodesOnUnifiedAddressThrowableError = KeyDerivationErrors.receiverNotFound
        await rustBackendMock.setCreateAccountSeedThrowableError(KeyDerivationErrors.unableToDerive)
        await rustBackendMock.setGetReceivedMemoIdNoteReturnValue(nil)
        await rustBackendMock.setGetSentMemoIdNoteReturnValue(nil)
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setInitDataDbSeedReturnValue(.seedRequired)
        ZcashRustBackendWeldingMock.isValidSaplingAddressNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidUnifiedAddressNetworkTypeReturnValue = false
        await rustBackendMock.setGetNearestRewindHeightHeightReturnValue(-1)
        await rustBackendMock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { _, _, _, _ in }
        await rustBackendMock.setPutUnspentTransparentOutputTxidIndexScriptValueHeightClosure() { _, _, _, _, _ in }
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        ZcashRustBackendWeldingMock.isValidSaplingExtendedFullViewingKeyNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidUnifiedFullViewingKeyNetworkTypeReturnValue = false
        ZcashRustBackendWeldingMock.isValidSaplingAddressNetworkTypeReturnValue = true
        ZcashRustBackendWeldingMock.isValidTransparentAddressNetworkTypeReturnValue = true
        await rustBackendMock.setCreateToAddressUskToValueMemoReturnValue(-1)
        await rustBackendMock.setDecryptAndStoreTransactionTxBytesMinedHeightThrowableError(RustWeldingError.genericError(message: "mock fail"))

        await rustBackendMock.setConsensusBranchIdForHeightClosure() { [weak self] height in
            guard let self else { return -1 }
            if let consensusBranchID = self.consensusBranchID {
                return consensusBranchID
            } else {
                return try await self.rustBackend.consensusBranchIdFor(height: height)
            }
        }

        await rustBackendMock.setInitDataDbSeedClosure() { [weak self] seed in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try await self.rustBackend.initDataDb(seed: seed)
        }

        await rustBackendMock.setInitBlocksTableHeightHashTimeSaplingTreeClosure() { [weak self] height, hash, time, saplingTree in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try await self.rustBackend.initBlocksTable(
                height: height,
                hash: hash,
                time: time,
                saplingTree: saplingTree
            )
        }

        await rustBackendMock.setGetBalanceAccountClosure() { [weak self] account in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try await self.rustBackend.getBalance(account: account)
        }

        await rustBackendMock.setGetVerifiedBalanceAccountClosure() { [weak self] account in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            return try await self.rustBackend.getVerifiedBalance(account: account)
        }

        await rustBackendMock.setValidateCombinedChainLimitClosure() { [weak self] limit in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            if let rate = self.mockValidateCombinedChainSuccessRate {
                if Self.shouldSucceed(successRate: rate) {
                    return try await self.rustBackend.validateCombinedChain(limit: limit)
                } else {
                    throw self.mockValidateCombinedChainFailureError
                }
            } else if let attempts = self.mockValidateCombinedChainFailAfterAttempts {
                self.mockValidateCombinedChainFailAfterAttempts = attempts - 1
                if attempts > 0 {
                    return try await self.rustBackend.validateCombinedChain(limit: limit)
                } else {
                    if attempts == 0 {
                        throw self.mockValidateCombinedChainFailureError
                    } else if attempts < 0 && self.mockValidateCombinedChainKeepFailing {
                        throw self.mockValidateCombinedChainFailureError
                    } else {
                        return try await self.rustBackend.validateCombinedChain(limit: limit)
                    }
                }
            } else {
                return try await self.rustBackend.validateCombinedChain(limit: limit)
            }
        }

        await rustBackendMock.setRewindToHeightHeightClosure() { [weak self] height in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try await self.rustBackend.rewindToHeight(height: height)
        }

        await rustBackendMock.setRewindCacheToHeightHeightClosure() { _ in }

        await rustBackendMock.setScanBlocksLimitClosure() { [weak self] limit in
            guard let self else { throw RustWeldingError.genericError(message: "Self is nil") }
            try await self.rustBackend.scanBlocks(limit: limit)
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
