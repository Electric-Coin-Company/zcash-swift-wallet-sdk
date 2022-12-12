//
//  InternalSyncProgress.swift
//  
//
//  Created by Michal Fousek on 23.11.2022.
//

import Foundation

struct SyncRanges: Equatable {
    let latestBlockHeight: BlockHeight
    let downloadRange: CompactBlockRange?
    let scanRange: CompactBlockRange?
    let enhanceRange: CompactBlockRange?
    let fetchUTXORange: CompactBlockRange?
}

protocol InternalSyncProgressStorage {
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func set(_ value: Int, forKey defaultName: String)
    func set(_ value: Bool, forKey defaultName: String)
    @discardableResult func synchronize() -> Bool
}

extension UserDefaults: InternalSyncProgressStorage { }

actor InternalSyncProgress {

    enum Key: String, CaseIterable {
        case latestDownloadedBlockHeight
        case latestEnhancedHeight
        case latestUTXOFetchedHeight
    }

    private let storage: InternalSyncProgressStorage

    var latestDownloadedBlockHeight: BlockHeight { get { get(.latestDownloadedBlockHeight) } }
    var latestEnhancedHeight: BlockHeight { get { get(.latestEnhancedHeight) } }
    var latestUTXOFetchedHeight: BlockHeight { get { get(.latestUTXOFetchedHeight) } }

    init(storage: InternalSyncProgressStorage) {
        self.storage = storage
    }

    func get(_ key: Key) -> BlockHeight {
        storage.integer(forKey: key.rawValue)
    }

    func set(_ value: BlockHeight, _ key: Key) {
        storage.set(value, forKey: key.rawValue)
        storage.synchronize()
    }

    func rewind(to: BlockHeight) {
        Key.allCases.forEach { key in
            let finalRewindHeight = min(self.get(key), to)
            self.set(finalRewindHeight, key)
        }
    }

    /// `InternalSyncProgress` is from now on used to track which block were already downloaded. Previous versions of the SDK were using cache DB to
    /// track this. Because of this we have to migrace height of latest downloaded block from cache DB to here.
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
    ) throws -> CompactBlockProcessor.NextState {
        LoggerProxy.debug("""
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
        } else if   latestDownloadedBlockHeight < latestBlockHeight ||
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
        return SyncRanges(
            latestBlockHeight: latestBlockHeight,
            downloadRange: computeRange(
                latestHeight: latestDownloadedBlockHeight,
                birthday: birthday,
                latestBlockHeight: latestBlockHeight
            ),
            scanRange: computeRange(
                latestHeight: latestScannedHeight,
                birthday: birthday,
                latestBlockHeight: latestBlockHeight
            ),
            enhanceRange: computeRange(latestHeight: latestEnhancedHeight, birthday: birthday, latestBlockHeight: latestBlockHeight),
            fetchUTXORange: computeRange(latestHeight: latestUTXOFetchedHeight, birthday: birthday, latestBlockHeight: latestBlockHeight)
        )
    }

    private func computeRange(latestHeight: BlockHeight, birthday: BlockHeight, latestBlockHeight: BlockHeight) -> CompactBlockRange? {
        guard latestHeight < latestBlockHeight else { return nil }
        let lowerBound = latestHeight <= birthday ? birthday : latestHeight + 1
        return lowerBound...latestBlockHeight
    }
}
