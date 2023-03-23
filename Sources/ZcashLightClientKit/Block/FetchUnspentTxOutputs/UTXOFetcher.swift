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
    let dataDb: URL
    let networkType: NetworkType
    let walletBirthdayProvider: () async -> BlockHeight
}

protocol UTXOFetcher {
    func fetch(at range: CompactBlockRange) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])
}

struct UTXOFetcherImpl {
    let accountRepository: AccountRepository
    let blockDownloaderService: BlockDownloaderService
    let config: UTXOFetcherConfig
    let internalSyncProgress: InternalSyncProgress
    let rustBackend: ZcashRustBackendWelding.Type
}

extension UTXOFetcherImpl: UTXOFetcher {
    func fetch(at range: CompactBlockRange) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]) {
        try Task.checkCancellation()

        let tAddresses = try accountRepository.getAll()
            .map { $0.account }
            .map {
                try rustBackend.listTransparentReceivers(
                    dbData: config.dataDb,
                    account: Int32($0),
                    networkType: config.networkType
                )
            }
            .flatMap({ $0 })

        var utxos: [UnspentTransactionOutputEntity] = []
        let stream: AsyncThrowingStream<UnspentTransactionOutputEntity, Error> = blockDownloaderService.fetchUnspentTransactionOutputs(
            tAddresses: tAddresses.map { $0.stringEncoded },
            startHeight: await config.walletBirthdayProvider()
        )

        for try await transaction in stream {
            utxos.append(transaction)
        }

        var refreshed: [UnspentTransactionOutputEntity] = []
        var skipped: [UnspentTransactionOutputEntity] = []

        let startTime = Date()
        for utxo in utxos {
            do {
                if try rustBackend.putUnspentTransparentOutput(
                    dbData: config.dataDb,
                    txid: utxo.txid.bytes,
                    index: utxo.index,
                    script: utxo.script.bytes,
                    value: Int64(utxo.valueZat),
                    height: utxo.height,
                    networkType: config.networkType
                ) {
                    refreshed.append(utxo)
                } else {
                    skipped.append(utxo)
                }

                await internalSyncProgress.set(utxo.height, .latestUTXOFetchedHeight)
            } catch {
                LoggerProxy.error("failed to put utxo - error: \(error)")
                skipped.append(utxo)
            }
        }

        SDKMetrics.shared.pushProgressReport(
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
            LoggerProxy.debug("Warning: fetchUnspentTxOutputs on range \(range) cancelled")
        }

        return result
    }
}
