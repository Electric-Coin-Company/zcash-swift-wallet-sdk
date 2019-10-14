//
//  Wallet.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
/**
 Wrapper for the Rust backend. This class basically represents all the Rust-wallet
 capabilities and the supporting data required to exercise those abilities.
 */


public enum WalletError: Error {
    case cacheDbInitFailed
}

public class Wallet {
    
    private var rustBackend: ZcashRustBackendWelding.Type
    private var dataDbURL: URL
    private var cacheDbURL: URL
    private var paramDestination: URL
    private var accountIDs: [Int]
    private var seedProvider: SeedProvider
    private var walletBirthday: WalletBirthday
    private var storage: Storage?
    
    init(rustWelding: ZcashRustBackendWelding.Type, cacheDbURL:URL, dataDbURL: URL, paramDestination: URL, seedProvider: SeedProvider, walletBirthday: WalletBirthday, accountIDs: [Int] = [0]) {
        
        self.rustBackend = rustWelding.self
        self.dataDbURL = dataDbURL
        self.paramDestination = paramDestination
        self.accountIDs = accountIDs
        self.seedProvider = seedProvider
        self.cacheDbURL = cacheDbURL
        self.walletBirthday = walletBirthday
        
    }
    
    
     public func initalize(firstRunStartHeight: BlockHeight = SAPLING_ACTIVATION_HEIGHT) throws {
        
        guard let storage = StorageBuilder.cacheDb(at: cacheDbURL) else {
            throw WalletError.cacheDbInitFailed
        }
        
        self.storage = storage
        
        
    }
    
    public func latestBlockHeight() -> Int? {
        try? self.storage?.compactBlockDao.latestBlockHeight()
    }
}



/**
    Represents the wallet's birthday which can be thought of as a checkpoint at the earliest moment in history where
    transactions related to this wallet could exist. Ideally, this would correspond to the latest block height at the
    time the wallet key was created. Worst case, the height of Sapling activation could be used (280000).
    
    Knowing a wallet's birthday can significantly reduce the amount of data that it needs to download because none of
    the data before that height needs to be scanned for transactions. However, we do need the Sapling tree data in
    order to construct valid transactions from that point forward. This birthday contains that tree data, allowing us
    to avoid downloading all the compact blocks required in order to generate it.
    
    New wallets can ignore any blocks created before their birthday.
    
    - Parameter height the height at the time the wallet was born
    - Parameter hash the block hash corresponding to the given height
    - Parameter time the time the wallet was born, in seconds
    - Parameter tree the sapling tree corresponding to the given height. This takes around 15 minutes of processing to
    generate from scratch because all blocks since activation need to be considered. So when it is calculated in
    advance it can save the user a lot of time.
    */
public struct WalletBirthday {
    var height: BlockHeight = -1
    var hash: String = ""
    var time: TimeInterval = -1
    var tree: String = ""
}
