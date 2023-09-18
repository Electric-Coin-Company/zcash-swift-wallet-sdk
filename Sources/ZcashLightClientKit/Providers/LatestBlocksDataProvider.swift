//
//  LatestBlocksDataProvider.swift
//  
//
//  Created by Lukáš Korba on 11.04.2023.
//

import Foundation

protocol LatestBlocksDataProvider {
    var fullyScannedHeight: BlockHeight { get async }
    var maxScannedHeight: BlockHeight { get async }
    var latestBlockHeight: BlockHeight { get async }
    var walletBirthday: BlockHeight { get async }

    func updateScannedData() async
    func updateBlockData() async
    func updateWalletBirthday(_ walletBirthday: BlockHeight) async
    func update(_ latestBlockHeight: BlockHeight) async
}

actor LatestBlocksDataProviderImpl: LatestBlocksDataProvider {
    let service: LightWalletService
    let rustBackend: ZcashRustBackendWelding
    
    // Valid values are stored here after Synchronizer's `prepare` is called.
    private(set) var fullyScannedHeight: BlockHeight = .zero
    private(set) var maxScannedHeight: BlockHeight = .zero
    // Valid value is stored here after block processor's `nextState` is called.
    private(set) var latestBlockHeight: BlockHeight = .zero
    // Valid values are stored here after Synchronizer's `prepare` is called.
    private(set) var walletBirthday: BlockHeight = .zero

    init(service: LightWalletService, rustBackend: ZcashRustBackendWelding) {
        self.service = service
        self.rustBackend = rustBackend
    }
    
    func updateScannedData() async {
        fullyScannedHeight = (try? await rustBackend.fullyScannedHeight()) ?? walletBirthday
        maxScannedHeight = (try? await rustBackend.maxScannedHeight()) ?? walletBirthday
    }

    func updateBlockData() async {
        if let newLatestBlockHeight = try? await service.latestBlockHeight() {
            await update(newLatestBlockHeight)
        }
    }

    func updateWalletBirthday(_ walletBirthday: BlockHeight) async {
        self.walletBirthday = walletBirthday
    }
    
    func update(_ newLatestBlockHeight: BlockHeight) async {
        if latestBlockHeight < newLatestBlockHeight {
            latestBlockHeight = newLatestBlockHeight
        }
    }
}
