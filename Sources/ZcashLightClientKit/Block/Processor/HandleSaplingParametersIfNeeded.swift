//
//  HandleSaplingParametersIfNeeded.swift
//  
//
//  Created by Lukáš Korba on 23.11.2022.
//

import Foundation

extension CompactBlockProcessor {
    func handleSaplingParametersIfNeeded() async throws {
        try Task.checkCancellation()
        
        state = .handlingSaplingFiles

        do {
            let verifiedBalance = try rustBackend.getVerifiedBalance(
                dbData: config.dataDb,
                account: Int32(0),
                networkType: config.network.networkType
            )

            let totalBalance = try rustBackend.getBalance(
                dbData: config.dataDb,
                account: Int32(0),
                networkType: config.network.networkType
            )

            // Download Sapling parameters only if sapling funds are detected.
            guard verifiedBalance > 0 || totalBalance > 0 else { return }
        } catch {
            // if sapling balance can't be detected of we fail to obtain the balance
            // for some reason we shall not proceed to download the parameters and
            // retry in the following attempt to sync.
            LoggerProxy.error("Couldn't Fetch shielded balance. Won't attempt to download sapling parameters")
            return
        }

        try await SaplingParameterDownloader.downloadParamsIfnotPresent(spendURL: config.spendParamsURL, outputURL: config.outputParamsURL)
    }
}
