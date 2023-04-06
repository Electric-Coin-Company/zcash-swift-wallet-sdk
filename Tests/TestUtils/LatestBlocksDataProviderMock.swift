//
//  LatestBlocksDataProviderMock.swift
//  
//
//  Created by Lukáš Korba on 12.04.2023.
//

import Foundation
@testable import ZcashLightClientKit

actor LatestBlocksDataProviderMock: LatestBlocksDataProvider {
    private(set) var latestScannedHeight: BlockHeight = .zero
    private(set) var latestScannedTime: TimeInterval = 0.0
    private(set) var latestBlockHeight: BlockHeight = .zero
    private(set) var walletBirthday: BlockHeight = .zero

    init(
        latestScannedHeight: BlockHeight = .zero,
        latestScannedTime: TimeInterval = 0,
        latestBlockHeight: BlockHeight = .zero,
        walletBirthday: BlockHeight = .zero
    ) {
        self.latestScannedHeight = latestScannedHeight
        self.latestScannedTime = latestScannedTime
        self.latestBlockHeight = latestBlockHeight
        self.walletBirthday = walletBirthday
    }
    
    func updateScannedData() async { }
    
    func updateBlockData() async { }
    
    func updateWalletBirthday(_ walletBirthday: BlockHeight) async { }
    
    func updateLatestScannedHeight(_ latestScannedHeight: BlockHeight) async { }
    
    func updateLatestScannedTime(_ latestScannedTime: TimeInterval) async { }
}
