//
//  LatestBlocksDataProvider.swift
//  
//
//  Created by Lukáš Korba on 11.04.2023.
//

import Foundation

protocol LatestBlocksDataProvider {
    var latestScannedHeight: BlockHeight { get async }
    var latestScannedTime: TimeInterval { get async }
    var latestBlockHeight: BlockHeight { get async }
    var walletBirthday: BlockHeight { get async }

    func updateScannedData() async
    func updateBlockData() async
    func updateWalletBirthday(_ walletBirthday: BlockHeight) async
    func updateLatestScannedHeight(_ latestScannedHeight: BlockHeight) async
    func updateLatestScannedTime(_ latestScannedTime: TimeInterval) async
}

actor LatestBlocksDataProviderImpl: LatestBlocksDataProvider {
    let service: LightWalletService
    let transactionRepository: TransactionRepository
    
    // Valid values are stored here after Synchronizer's `prepare` is called.
    private(set) var latestScannedHeight: BlockHeight = .zero
    private(set) var latestScannedTime: TimeInterval = 0.0
    // Valid value is stored here after block processor's `nextState` is called.
    private(set) var latestBlockHeight: BlockHeight = .zero
    // Valid values are stored here after Synchronizer's `prepare` is called.
    private(set) var walletBirthday: BlockHeight = .zero

    init(service: LightWalletService, transactionRepository: TransactionRepository) {
        self.service = service
        self.transactionRepository = transactionRepository
    }
    
    /// Call of this function is potentially dangerous and can result in `database lock` errors.
    /// Typical use is outside of a sync process. Example: Synchronizer's prepare function, call there is a safe one.
    /// The update of `latestScannedHeight` and `latestScannedTime` during the syncing is done via
    /// appropriate `updateX()` methods inside `BlockScanner` so `transactionRepository` is omitted.
    func updateScannedData() async {
        latestScannedHeight = (try? await transactionRepository.lastScannedHeight()) ?? walletBirthday
        if let time = try? await transactionRepository.blockForHeight(latestScannedHeight)?.time {
            latestScannedTime = TimeInterval(time)
        }
    }
    
    func updateBlockData() async {
        if let newLatestBlockHeight = try? await service.latestBlockHeight(),
        latestBlockHeight < newLatestBlockHeight {
            latestBlockHeight = newLatestBlockHeight
        }
    }
    
    func updateWalletBirthday(_ walletBirthday: BlockHeight) async {
        self.walletBirthday = walletBirthday
    }
    
    func updateLatestScannedHeight(_ latestScannedHeight: BlockHeight) async {
        self.latestScannedHeight = latestScannedHeight
    }
    
    func updateLatestScannedTime(_ latestScannedTime: TimeInterval) async {
        self.latestScannedTime = latestScannedTime
    }
}
