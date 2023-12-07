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

extension String: Error { }

class AwfulLightWalletService: MockLightWalletService {
    override func latestBlockHeight() async throws -> BlockHeight {
        throw ZcashError.serviceLatestBlockFailed(.criticalError)
    }

    override func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: ZcashError.serviceSubmitFailed(.invalidBlock)) }
    }

    /// Submits a raw transaction over lightwalletd.
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        throw ZcashError.serviceSubmitFailed(.invalidBlock)
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

    init(
        rustBackend: ZcashRustBackendWelding,
        consensusBranchID: Int32? = nil
    ) async {
        self.rustBackendMock = ZcashRustBackendWeldingMock()
        rustBackendMock.consensusBranchIdForHeightClosure = { height in
            if let consensusBranchID {
                return consensusBranchID
            } else {
                return try rustBackend.consensusBranchIdFor(height: height)
            }
        }
        setupDefaultMock(rustBackend: rustBackend)
    }

    private func setupDefaultMock(rustBackend: ZcashRustBackendWelding) {
        rustBackendMock.latestCachedBlockHeightReturnValue = .empty()
        rustBackendMock.initBlockMetadataDbClosure = { }
        rustBackendMock.writeBlocksMetadataBlocksClosure = { _ in }
        rustBackendMock.getTransparentBalanceAccountReturnValue = 0
        rustBackendMock.getVerifiedBalanceAccountReturnValue = 0
        rustBackendMock.listTransparentReceiversAccountReturnValue = []
        rustBackendMock.getCurrentAddressAccountThrowableError = ZcashError.rustGetCurrentAddress("mocked error")
        rustBackendMock.getNextAvailableAddressAccountThrowableError = ZcashError.rustGetNextAvailableAddress("mocked error")
        rustBackendMock.createAccountSeedTreeStateRecoverUntilThrowableError = ZcashError.rustInitAccountsTableViewingKeyCotainsNullBytes
        rustBackendMock.getMemoTxIdOutputIndexReturnValue = nil
        rustBackendMock.initDataDbSeedReturnValue = .seedRequired
        rustBackendMock.getNearestRewindHeightHeightReturnValue = -1
        rustBackendMock.putUnspentTransparentOutputTxidIndexScriptValueHeightClosure = { _, _, _, _, _ in }
        rustBackendMock.createToAddressUskToValueMemoThrowableError = ZcashError.rustCreateToAddress("mocked error")
        rustBackendMock.shieldFundsUskMemoShieldingThresholdThrowableError = ZcashError.rustShieldFunds("mocked error")
        rustBackendMock.decryptAndStoreTransactionTxBytesMinedHeightThrowableError = ZcashError.rustDecryptAndStoreTransaction("mock fail")

        rustBackendMock.initDataDbSeedClosure = { seed in
            return try await rustBackend.initDataDb(seed: seed)
        }

        rustBackendMock.getBalanceAccountClosure = { account in
            return try await rustBackend.getBalance(account: account)
        }

        rustBackendMock.getVerifiedBalanceAccountClosure = { account in
            return try await rustBackend.getVerifiedBalance(account: account)
        }

        rustBackendMock.rewindToHeightHeightClosure = { height in
            try await rustBackend.rewindToHeight(height: height)
        }

        rustBackendMock.rewindCacheToHeightHeightClosure = { _ in }

        rustBackendMock.suggestScanRangesClosure = {
            try await rustBackend.suggestScanRanges()
        }

        rustBackendMock.scanBlocksFromHeightLimitClosure = { fromHeight, limit in
            try await rustBackend.scanBlocks(fromHeight: fromHeight, limit: limit)
        }
    }

    private static func shouldSucceed(successRate: Float) -> Bool {
        let random = Float.random(in: 0.0...1.0)
        return random <= successRate
    }
}

extension SaplingParamsSourceURL {
    static let tests = SaplingParamsSourceURL(
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

extension SynchronizerState {
    static var mock: SynchronizerState {
        SynchronizerState(
            syncSessionID: .nullID,
            shieldedBalance: WalletBalance(verified: Zatoshi(100), total: Zatoshi(200)),
            transparentBalance: WalletBalance(verified: Zatoshi(200), total: Zatoshi(300)),
            internalSyncStatus: .syncing(0),
            latestBlockHeight: 222222
        )
    }
}
