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

        let balance = WalletBalance(
            verified: Zatoshi(
                rustBackend.getVerifiedBalance(
                    dbData: config.dataDb,
                    account: Int32(0),
                    networkType: config.network.networkType)
            ),
            total: Zatoshi(
                rustBackend.getBalance(
                    dbData: config.dataDb,
                    account: Int32(0),
                    networkType: config.network.networkType
                )
            )
        )
        
        guard balance.verified.amount > 0 || balance.total.amount > 0 else {
            return
        }
        
        try await SaplingParameterDownloader.downloadParamsIfnotPresent(spendURL: config.spendParamsURL, outputURL: config.outputParamsURL)
    }
}
