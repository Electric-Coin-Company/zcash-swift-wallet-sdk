//
//  FetchUnspentTxOutputs.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 6/2/21.
//

import Foundation

extension CompactBlockProcessor {
    enum FetchUTXOError: Error {
        case clearingFailed(_ error: Error?)
        case fetchFailed(error: Error)
    }

    func fetchUnspentTxOutputs(range: CompactBlockRange) async throws {
        try Task.checkCancellation()
        
        state = .fetching

        do {
            let tAddresses = try accountRepository.getAll().map({ $0.transparentAddress })
            do {
                for tAddress in tAddresses {
                    guard try rustBackend.clearUtxos(
                        dbData: config.dataDb,
                        address: tAddress,
                        sinceHeight: config.walletBirthday - 1,
                        networkType: config.network.networkType
                    ) >= 0 else {
                        throw rustBackend.lastError() ?? RustWeldingError.genericError(message: "attempted to clear utxos but -1 was returned")
                    }
                }
            } catch {
                throw FetchUTXOError.clearingFailed(error)
            }
            
            var utxos: [UnspentTransactionOutputEntity] = []
            let stream: AsyncThrowingStream<UnspentTransactionOutputEntity, Error> = downloader.fetchUnspentTransactionOutputs(tAddresses: tAddresses, startHeight: config.walletBirthday)
            for try await transaction in stream {
                utxos.append(transaction)
            }
            
            var refreshed: [UnspentTransactionOutputEntity] = []
            var skipped: [UnspentTransactionOutputEntity] = []

            for utxo in utxos {
                do {
                    try rustBackend.putUnspentTransparentOutput(
                        dbData: config.dataDb,
                        address: utxo.address,
                        txid: utxo.txid.bytes,
                        index: utxo.index,
                        script: utxo.script.bytes,
                        value: Int64(utxo.valueZat),
                        height: utxo.height,
                        networkType: config.network.networkType
                    ) ? refreshed.append(utxo) : skipped.append(utxo)
                } catch {
                    LoggerProxy.error("failed to put utxo - error: \(error)")
                    skipped.append(utxo)
                }
            }

            let result = (inserted: refreshed, skipped: skipped)
            
            NotificationCenter.default.mainThreadPost(
                name: .blockProcessorStoredUTXOs,
                object: self,
                userInfo: [CompactBlockProcessorNotificationKey.refreshedUTXOs: result]
            )
            
            if Task.isCancelled {
                LoggerProxy.debug("Warning: fetchUnspentTxOutputs on range \(range) cancelled")
            } else {
                await processBatchFinished(range: range)
            }
        } catch {
            throw error
        }
    }
}
