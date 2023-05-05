//
//  InternalSyncProgress.swift
//  
//
//  Created by Michal Fousek on 23.11.2022.
//

import Foundation

struct SyncRanges: Equatable {
    let latestBlockHeight: BlockHeight
    /// The sync process can be interrupted in any phase. It may happen that it's interrupted while downloading blocks. In that case in next sync
    /// process already downloaded blocks needs to be scanned before the sync process starts to download new blocks. And the range of blocks that are
    /// already downloaded but not scanned is stored in this variable.
    let downloadedButUnscannedRange: CompactBlockRange?
    /// Range of blocks that are not yet downloaded and not yet scanned.
    let downloadAndScanRange: CompactBlockRange?
    /// Range of blocks that are not enhanced yet.
    let enhanceRange: CompactBlockRange?
    /// Range of blocks for which no UTXOs are fetched yet.
    let fetchUTXORange: CompactBlockRange?

    let latestScannedHeight: BlockHeight?

    let latestDownloadedBlockHeight: BlockHeight?

    static var empty: SyncRanges {
        SyncRanges(
            latestBlockHeight: 0,
            downloadedButUnscannedRange: nil,
            downloadAndScanRange: nil,
            enhanceRange: nil,
            fetchUTXORange: nil,
            latestScannedHeight: nil,
            latestDownloadedBlockHeight: nil
        )
    }
}

protocol InternalSyncProgressStorage {
    func initialize() async throws
    func bool(for key: String) async throws -> Bool
    func integer(for key: String) async throws -> Int
    func set(_ value: Int, for key: String) async throws
    func set(_ value: Bool, for key: String) async throws
}

actor InternalSyncProgress {
    enum Key: String, CaseIterable {
        case latestDownloadedBlockHeight
        case latestEnhancedHeight
        case latestUTXOFetchedHeight

        func with(_ alias: ZcashSynchronizerAlias) -> String {
            switch alias {
            case .`default`:
                return self.rawValue
            case let .custom(rawAlias):
                return "\(self.rawValue)_\(rawAlias)"
            }
        }
    }

    private let alias: ZcashSynchronizerAlias
    private let storage: InternalSyncProgressStorage
    let logger: Logger

    var latestDownloadedBlockHeight: BlockHeight {
        get async throws { try await load(.latestDownloadedBlockHeight) }
    }
    var latestEnhancedHeight: BlockHeight {
        get async throws { try await load(.latestEnhancedHeight) }
    }
    var latestUTXOFetchedHeight: BlockHeight {
        get async throws { try await load(.latestUTXOFetchedHeight) }
    }

    init(alias: ZcashSynchronizerAlias, storage: InternalSyncProgressStorage, logger: Logger) {
        self.alias = alias
        self.storage = storage
        self.logger = logger
    }

    func initialize() async throws {
        try await storage.initialize()
    }

    func load(_ key: Key) async throws -> BlockHeight {
        return try await storage.integer(for: key.with(alias))
    }

    func set(_ value: BlockHeight, _ key: Key) async throws {
        try await storage.set(value, for: key.with(alias))
    }

    func rewind(to: BlockHeight) async throws {
        for key in Key.allCases {
            let finalRewindHeight = min(try await load(key), to)
            try await self.set(finalRewindHeight, key)
        }
    }

    /// `InternalSyncProgress` is from now on used to track which block were already downloaded. Previous versions of the SDK were using cache DB to
    /// track this. Because of this we have to migrate height of latest downloaded block from cache DB to here.
    ///
    /// - Parameter latestDownloadedBlockHeight: Height of latest downloaded block from cache DB.
    func migrateIfNeeded(
        latestDownloadedBlockHeightFromCacheDB latestDownloadedBlockHeight: BlockHeight,
        alias: ZcashSynchronizerAlias
    ) async throws {
        // If no latest downloaded height is stored in storage store there latest downloaded height from blocks storage. If there are no blocks
        // downloaded then it will be 0 anyway. If there are blocks downloaded real height is stored.
        if try await storage.integer(for: Key.latestDownloadedBlockHeight.with(alias)) == 0 {
            try await set(latestDownloadedBlockHeight, .latestDownloadedBlockHeight)
        }

        for key in Key.allCases {
            let finalKey = key.with(alias)
            let value = UserDefaults.standard.integer(forKey: finalKey)
            if value > 0 {
                try await storage.set(value, for: finalKey)
            }
            UserDefaults.standard.set(0, forKey: finalKey)
        }
    }

    /// Computes the next state for the sync process. Thanks to this it's possible to interrupt the sync process at any phase and then it can be safely
    /// resumed.
    ///
    /// The sync process has 4 phases (download, scan, enhance, fetch UTXO). `InternalSyncProgress` tracks independently which blocks were already
    /// processed in each phase. To compute the next state these 4 numbers are compared with `latestBlockHeight`.
    ///
    /// - If any of these numbers are larger than `latestBlockHeight` then `wait` is used as the next state. We have locally higher block heights than
    ///   are currently available at LightWalletd.
    /// - If any of these numbers are lower than `latestBlockHeight` then `processNewBlocks` is used as the next state. The sync process should run.
    /// - Otherwise `finishProcessing` is used as the next state. It means that local data are synced with what is available at LightWalletd.
    ///
    /// - Parameters:
    ///   - latestBlockHeight: Latest height fetched from LightWalletd API.
    ///   - latestScannedHeight: Latest height of latest block scanned.
    ///   - walletBirthday: Wallet birthday.
    /// - Returns: Computed state.
    func computeNextState(
        latestBlockHeight: BlockHeight,
        latestScannedHeight: BlockHeight,
        walletBirthday: BlockHeight
    ) async throws -> CompactBlockProcessor.NextState {
        let latestDownloadedBlockHeight = try await self.latestDownloadedBlockHeight
        let latestEnhancedHeight = try await self.latestEnhancedHeight
        let latestUTXOFetchedHeight = try await self.latestUTXOFetchedHeight
        logger.debug("""
            Init numbers:
            latestBlockHeight:       \(latestBlockHeight)
            latestDownloadedHeight:  \(latestDownloadedBlockHeight)
            latestScannedHeight:     \(latestScannedHeight)
            latestEnhancedHeight:    \(latestEnhancedHeight)
            latestUTXOFetchedHeight: \(latestUTXOFetchedHeight)
            """)

        if  latestDownloadedBlockHeight > latestBlockHeight ||
            latestScannedHeight > latestBlockHeight ||
            latestEnhancedHeight > latestBlockHeight ||
            latestUTXOFetchedHeight > latestBlockHeight {
            return .wait(latestHeight: latestBlockHeight, latestDownloadHeight: latestDownloadedBlockHeight)
        } else if latestDownloadedBlockHeight < latestBlockHeight ||
            latestScannedHeight < latestBlockHeight ||
            latestEnhancedHeight < latestEnhancedHeight ||
            latestUTXOFetchedHeight < latestBlockHeight {
            let ranges = try await computeSyncRanges(
                birthday: walletBirthday,
                latestBlockHeight: latestBlockHeight,
                latestScannedHeight: latestScannedHeight
            )
            return .processNewBlocks(ranges: ranges)
        } else {
            return .finishProcessing(height: latestBlockHeight)
        }
    }

    func computeSyncRanges(
        birthday: BlockHeight,
        latestBlockHeight: BlockHeight,
        latestScannedHeight: BlockHeight
    ) async throws -> SyncRanges {
        let latestDownloadedBlockHeight = try await self.latestDownloadedBlockHeight
        let latestEnhancedHeight = try await self.latestEnhancedHeight
        let latestUTXOFetchedHeight = try await self.latestUTXOFetchedHeight

        // If there is more downloaded then scanned blocks we have to range for these blocks. The sync process will then start with scanning these
        // blocks instead of downloading new ones.
        let downloadedButUnscannedRange: CompactBlockRange?
        if latestScannedHeight < latestDownloadedBlockHeight {
            downloadedButUnscannedRange = latestScannedHeight + 1...latestDownloadedBlockHeight
        } else {
            downloadedButUnscannedRange = nil
        }

        if latestScannedHeight > latestDownloadedBlockHeight {
            logger.warn("""
            InternalSyncProgress found inconsistent state.
                latestBlockHeight:       \(latestBlockHeight)
            --> latestDownloadedHeight:  \(latestDownloadedBlockHeight)
                latestScannedHeight:     \(latestScannedHeight)
                latestEnhancedHeight:    \(latestEnhancedHeight)
                latestUTXOFetchedHeight: \(latestUTXOFetchedHeight)

            latest downloaded height
            """)
        }

        // compute the range that must be downloaded and scanned based on
        // birthday, `latestDownloadedBlockHeight`, `latestScannedHeight` and
        // latest block height fetched from the chain.
        let downloadAndScanRange = computeRange(
            latestHeight: max(latestDownloadedBlockHeight, latestScannedHeight),
            birthday: birthday,
            latestBlockHeight: latestBlockHeight
        )

        return SyncRanges(
            latestBlockHeight: latestBlockHeight,
            downloadedButUnscannedRange: downloadedButUnscannedRange,
            downloadAndScanRange: downloadAndScanRange,
            enhanceRange: computeRange(latestHeight: latestEnhancedHeight, birthday: birthday, latestBlockHeight: latestBlockHeight),
            fetchUTXORange: computeRange(latestHeight: latestUTXOFetchedHeight, birthday: birthday, latestBlockHeight: latestBlockHeight),
            latestScannedHeight: latestScannedHeight,
            latestDownloadedBlockHeight: latestDownloadedBlockHeight
        )
    }

    private func computeRange(latestHeight: BlockHeight, birthday: BlockHeight, latestBlockHeight: BlockHeight) -> CompactBlockRange? {
        guard latestHeight < latestBlockHeight else { return nil }
        let lowerBound = latestHeight <= birthday ? birthday : latestHeight + 1
        return lowerBound...latestBlockHeight
    }
}
