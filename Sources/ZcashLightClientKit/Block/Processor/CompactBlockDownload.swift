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
            
            for try await zcashCompactBlock in stream {
                try Task.checkCancellation()
                buffer.append(zcashCompactBlock)
                if buffer.count >= blockBufferSize {
                    try await storage.write(blocks: buffer)
                    await blocksBufferWritten(buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
                
                let progress = BlockProgress(
                    startHeight: startHeight,
                    targetHeight: latestHeight,
                    progressHeight: zcashCompactBlock.height
                )
                notifyProgress(.download(progress))
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
