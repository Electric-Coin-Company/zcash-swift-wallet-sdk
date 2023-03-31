//
//  HandleSaplingParametersIfNeeded.swift
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
            let totalShieldedBalance = try await rustBackend.getBalance(account: Int32(0))
            let totalTransparentBalance = try await rustBackend.getTransparentBalance(account: Int32(0))

            // Download Sapling parameters only if sapling funds are detected.
            guard totalShieldedBalance > 0 || totalTransparentBalance > 0 else { return }
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
