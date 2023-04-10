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
}

protocol InternalSyncProgressStorage {
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func set(_ value: Int, forKey defaultName: String)
    func set(_ value: Bool, forKey defaultName: String)
    @discardableResult
    func synchronize() -> Bool
}

extension UserDefaults: InternalSyncProgressStorage { }

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

    var latestDownloadedBlockHeight: BlockHeight { load(.latestDownloadedBlockHeight) }
    var latestEnhancedHeight: BlockHeight { load(.latestEnhancedHeight) }
    var latestUTXOFetchedHeight: BlockHeight { load(.latestUTXOFetchedHeight) }

    init(alias: ZcashSynchronizerAlias, storage: InternalSyncProgressStorage, logger: Logger) {
        self.alias = alias
        self.storage = storage
        self.logger = logger
    }

    func load(_ key: Key) -> BlockHeight {
        storage.integer(forKey: key.with(alias))
    }

    func set(_ value: BlockHeight, _ key: Key) {
        storage.set(value, forKey: key.with(alias))
        storage.synchronize()
    }

    func rewind(to: BlockHeight) {
        Key.allCases.forEach { key in
            let finalRewindHeight = min(load(key), to)
            self.set(finalRewindHeight, key)
        }
    }

    /// `InternalSyncProgress` is from now on used to track which block were already downloaded. Previous versions of the SDK were using cache DB to
    /// track this. Because of this we have to migrate height of latest downloaded block from cache DB to here.
    ///
    /// - Parameter latestDownloadedBlockHeight: Height of latest downloaded block from cache DB.
    func migrateIfNeeded(latestDownloadedBlockHeightFromCacheDB latestDownloadedBlockHeight: BlockHeight) {
        let key = "InternalSyncProgressMigrated"
        if !storage.bool(forKey: key) {
            set(latestDownloadedBlockHeight, .latestDownloadedBlockHeight)
        }
        storage.set(true, forKey: key)
        storage.synchronize()
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
    ) -> CompactBlockProcessor.NextState {
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
            let ranges = computeSyncRanges(
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
    ) -> SyncRanges {
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
