//
//  CompactBlockDownload.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension CompactBlockProcessor {
    func compactBlockStreamDownload(
        blockBufferSize: Int,
        startHeight: BlockHeight? = nil,
        targetHeight: BlockHeight? = nil
    ) async throws {
        try Task.checkCancellation()
        
        state = .downloading
        
        var buffer: [ZcashCompactBlock] = []
        var targetHeightInternal: BlockHeight?
        
        do {
            var startTime = Date()
            targetHeightInternal = targetHeight
            if targetHeight == nil {
                targetHeightInternal = try await service.latestBlockHeightAsync()
            }
            guard let latestHeight = targetHeightInternal else {
                throw LightWalletServiceError.generalError(message: "missing target height on compactBlockStreamDownload")
            }
            try Task.checkCancellation()
            let latestDownloaded = try storage.latestBlockHeight()
            let startHeight = max(startHeight ?? BlockHeight.empty(), latestDownloaded)

            let stream = service.blockStream(
                startHeight: startHeight,
                endHeight: latestHeight
            )
            
            var counter = 0
            var lastDownloadedBlockHeight = -1
            
            for try await zcashCompactBlock in stream {
                try Task.checkCancellation()
                buffer.append(zcashCompactBlock)
                counter += 1
                lastDownloadedBlockHeight = zcashCompactBlock.height
                
                let progress = BlockProgress(
                    startHeight: startHeight,
                    targetHeight: latestHeight,
                    progressHeight: lastDownloadedBlockHeight
                )
                notifyProgress(.download(progress))

                if buffer.count >= blockBufferSize {
                    let finishTime = Date()
                    try await storage.write(blocks: buffer)
                    await blocksBufferWritten(buffer)
                    buffer.removeAll(keepingCapacity: true)
                    
                    SDKMetrics.shared.pushProgressReport(
                        progress: progress,
                        start: startTime,
                        end: finishTime,
                        batchSize: Int(blockBufferSize),
                        operation: .downloadBlocks
                    )
                    counter = 0
                    startTime = finishTime
                }
            }
            if counter > 0 {
                SDKMetrics.shared.pushProgressReport(
                    progress: BlockProgress(
                        startHeight: startHeight,
                        targetHeight: latestHeight,
                        progressHeight: lastDownloadedBlockHeight
                    ),
                    start: startTime,
                    end: Date(),
                    batchSize: Int(blockBufferSize),
                    operation: .downloadBlocks
                )
            }
            
            try await storage.write(blocks: buffer)
            await blocksBufferWritten(buffer)
            buffer.removeAll(keepingCapacity: true)
        } catch {
            guard let err = error as? LightWalletServiceError, case .userCancelled = err else {
                throw error
            }
        }
    }

    private func blocksBufferWritten(_ buffer: [ZcashCompactBlock]) async {
        guard let lastBlock = buffer.last else { return }
        await internalSyncProgress.set(lastBlock.height, .latestDownloadedBlockHeight)
    }
}

extension CompactBlockProcessor {
    func compactBlockDownload(
        downloader: CompactBlockDownloading,
        range: CompactBlockRange
    ) async throws {
        try Task.checkCancellation()
        
        do {
            try await downloader.downloadBlockRange(range)
        } catch {
            throw error
        }
    }
}
