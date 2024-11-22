//
//  SaplingParametersHandler.swift
//
//
//  Created by Lukáš Korba on 23.11.2022.
//

import Foundation

struct SaplingParametersHandlerConfig {
    let outputParamsURL: URL
    let spendParamsURL: URL
    let saplingParamsSourceURL: SaplingParamsSourceURL
}

protocol SaplingParametersHandler {
    func handleIfNeeded(account: Zip32Account) async throws
}

struct SaplingParametersHandlerImpl {
    let config: SaplingParametersHandlerConfig
    let rustBackend: ZcashRustBackendWelding
    let logger: Logger
}

extension SaplingParametersHandlerImpl: SaplingParametersHandler {
    func handleIfNeeded(account: Zip32Account) async throws {
        try Task.checkCancellation()

        do {
            let totalSaplingBalance =
                try await rustBackend.getWalletSummary()?.accountBalances[0]?.saplingBalance.total().amount
                ?? 0
            let totalTransparentBalance = try await rustBackend.getTransparentBalance(account: account)

            // Download Sapling parameters only if sapling funds are detected.
            guard totalSaplingBalance > 0 || totalTransparentBalance > 0 else { return }
        } catch {
            // if sapling balance can't be detected of we fail to obtain the balance
            // for some reason we shall not proceed to download the parameters and
            // retry in the following attempt to sync.
            logger.error("Couldn't Fetch shielded balance. Won't attempt to download sapling parameters")
            return
        }

        try await SaplingParameterDownloader.downloadParamsIfnotPresent(
            spendURL: config.spendParamsURL,
            spendSourceURL: config.saplingParamsSourceURL.spendParamFileURL,
            outputURL: config.outputParamsURL,
            outputSourceURL: config.saplingParamsSourceURL.outputParamFileURL,
            logger: logger
        )
    }
}
