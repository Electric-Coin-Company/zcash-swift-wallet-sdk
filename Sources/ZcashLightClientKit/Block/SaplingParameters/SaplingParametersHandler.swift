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
    func handleIfNeeded() async throws
}

struct SaplingParametersHandlerImpl {
    let config: SaplingParametersHandlerConfig
    let rustBackend: ZcashRustBackendWelding
    let logger: Logger
}

extension SaplingParametersHandlerImpl: SaplingParametersHandler {
    func handleIfNeeded() async throws {
        try Task.checkCancellation()

        do {
            let accounts = try await rustBackend.listAccounts()

            var totalSaplingBalanceTrigger = false
            var totalTransparentBalanceTrigger = false

            for account in accounts {
                let zip32AccountIndex = Zip32AccountIndex(account.index)
                
                let totalSaplingBalance =
                try await rustBackend.getWalletSummary()?.accountBalances[zip32AccountIndex]?.saplingBalance.total().amount
                    ?? 0

                if totalSaplingBalance > 0 {
                    totalSaplingBalanceTrigger = true
                    break
                }

                let totalTransparentBalance = try await rustBackend.getTransparentBalance(accountIndex: zip32AccountIndex)

                if totalTransparentBalance > 0 {
                    totalTransparentBalanceTrigger = true
                    break
                }
            }
            
            // Download Sapling parameters only if sapling funds are detected.
            guard totalSaplingBalanceTrigger || totalTransparentBalanceTrigger else { return }
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
