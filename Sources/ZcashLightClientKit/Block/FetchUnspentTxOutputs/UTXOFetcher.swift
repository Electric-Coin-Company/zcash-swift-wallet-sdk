//
//  UTXOFetcher.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 6/2/21.
//

import Foundation

enum UTXOFetcherError: Error {
    case clearingFailed(_ error: Error?)
    case fetchFailed(error: Error)
}

struct UTXOFetcherConfig {
    let walletBirthdayProvider: () async -> BlockHeight
}

protocol UTXOFetcher {
    func fetch(
        didFetch: @escaping (Float) async -> Void
    ) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])
}

struct UTXOFetcherImpl {
    let blockDownloaderService: BlockDownloaderService
    let config: UTXOFetcherConfig
    let rustBackend: ZcashRustBackendWelding
    let metrics: SDKMetrics
    let logger: Logger
}

extension UTXOFetcherImpl: UTXOFetcher {
    func fetch(
        didFetch: @escaping (Float) async -> Void
    ) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]) {
        try Task.checkCancellation()

        let accounts = try await rustBackend.listAccounts()

        var tAddresses: [TransparentAddress] = []
        for account in accounts {
            tAddresses += try await rustBackend.listTransparentReceivers(account: Int32(account))
        }

        var utxos: [UnspentTransactionOutputEntity] = []
        let stream: AsyncThrowingStream<UnspentTransactionOutputEntity, Error> = blockDownloaderService.fetchUnspentTransactionOutputs(
            tAddresses: tAddresses.map { $0.stringEncoded },
            startHeight: await config.walletBirthdayProvider()
        )

        do {
            for try await transaction in stream {
                utxos.append(transaction)
            }
        } catch {
            throw ZcashError.unspentTransactionFetcherStream(error)
        }

        var refreshed: [UnspentTransactionOutputEntity] = []
        var skipped: [UnspentTransactionOutputEntity] = []

        let all = Float(utxos.count)
        var counter = Float(0)
        for utxo in utxos {
            do {
                try await rustBackend.putUnspentTransparentOutput(
                    txid: utxo.txid.bytes,
                    index: utxo.index,
                    script: utxo.script.bytes,
                    value: Int64(utxo.valueZat),
                    height: utxo.height
                )

                refreshed.append(utxo)

                counter += 1
                await didFetch(counter / all)
            } catch {
                logger.error("failed to put utxo - error: \(error)")
                skipped.append(utxo)
            }
        }

        let result = (inserted: refreshed, skipped: skipped)

        if Task.isCancelled {
            logger.debug("Warning: fetchUnspentTxOutputs cancelled")
        }

        return result
    }
}
