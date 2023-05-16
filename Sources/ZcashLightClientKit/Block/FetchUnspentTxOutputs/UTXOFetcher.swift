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
        at range: CompactBlockRange,
        didFetch: (Float) async -> Void
    ) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])
}

struct UTXOFetcherImpl {
    let accountRepository: AccountRepository
    let blockDownloaderService: BlockDownloaderService
    let config: UTXOFetcherConfig
    let internalSyncProgress: InternalSyncProgress
    let rustBackend: ZcashRustBackendWelding
    let metrics: SDKMetrics
    let logger: Logger
}

extension UTXOFetcherImpl: UTXOFetcher {
    func fetch(
        at range: CompactBlockRange,
        didFetch: (Float) async -> Void
    ) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]) {
        try Task.checkCancellation()

        let accounts = try accountRepository.getAll()
            .map { $0.account }

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

        let startTime = Date()
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
                await internalSyncProgress.set(utxo.height, .latestUTXOFetchedHeight)
            } catch {
                logger.error("failed to put utxo - error: \(error)")
                skipped.append(utxo)
            }
        }

        metrics.pushProgressReport(
            progress: BlockProgress(
                startHeight: range.lowerBound,
                targetHeight: range.upperBound,
                progressHeight: range.upperBound
            ),
            start: startTime,
            end: Date(),
            batchSize: range.count,
            operation: .fetchUTXOs
        )

        let result = (inserted: refreshed, skipped: skipped)

        await internalSyncProgress.set(range.upperBound, .latestUTXOFetchedHeight)

        if Task.isCancelled {
            logger.debug("Warning: fetchUnspentTxOutputs on range \(range) cancelled")
        }

        return result
    }
}
