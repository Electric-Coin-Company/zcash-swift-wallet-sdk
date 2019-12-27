//
//  Initializer.swift
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

public enum InitializerError: Error {
    case cacheDbInitFailed
    case dataDbInitFailed
    case accountInitFailed
    case falseStart
}

public struct LightWalletEndpoint {
    public var address: String
    public var port: String
    public var secure: Bool
    
    public var host: String {
        "\(address):\(port)"
    }
    
    public init(address: String, port: String, secure: Bool = true) {
        self.address = address
        self.port = port
        self.secure = secure
    }
}

/**
 Wrapper for all the Rust backend functionality that does not involve processing blocks. This
 class initializes the Rust backend and the supporting data required to exercise those abilities.
 The [cash.z.wallet.sdk.block.CompactBlockProcessor] handles all the remaining Rust backend
 functionality, related to processing blocks.
 */
public class Initializer {
    
    private(set) var rustBackend: ZcashRustBackendWelding.Type = ZcashRustBackend.self
    private var lowerBoundHeight: BlockHeight = ZcashSDK.SAPLING_ACTIVATION_HEIGHT
    private(set) var cacheDbURL: URL
    private(set) var dataDbURL: URL
    private(set) var pendingDbURL: URL
    private(set) var spendParamsURL: URL
    private(set) var outputParamsURL: URL
    private var walletBirthday: WalletBirthday?
    
    public private(set) var endpoint: LightWalletEndpoint
    
    public init (cacheDbURL: URL, dataDbURL: URL, pendingDbURL: URL, endpoint: LightWalletEndpoint, spendParamsURL: URL, outputParamsURL: URL) {
        self.cacheDbURL = cacheDbURL
        self.dataDbURL = dataDbURL
        self.endpoint = endpoint
        self.pendingDbURL = pendingDbURL
        self.spendParamsURL = spendParamsURL
        self.outputParamsURL = outputParamsURL
    }
    
    /**
     Initialize the wallet with the given seed and return the related private keys for each
     account specified or null if the wallet was previously initialized and block data exists on
     disk. When this method returns null, that signals that the wallet will need to retrieve the
     private keys from its own secure storage. In other words, the private keys are only given out
     once for each set of database files. Subsequent calls to [initialize] will only load the Rust
     library and return null.
     
     'compactBlockCache.db' and 'transactionData.db' files are created by this function (if they
     do not already exist). These files can be given a prefix for scenarios where multiple wallets
     operate in one app--for instance, when sweeping funds from another wallet seed.
     - Parameter seedProvider   the seed to use for initializing this wallet.
     - Parameter walletBirthdayHeight the height corresponding to when the wallet seed was created. If null,
     this signals that the wallet is being born.
     - Parameter numberOfAccounts the number of accounts to create from this seed.
     */
    
    public func initialize(seedProvider: SeedProvider, walletBirthdayHeight: BlockHeight, numberOfAccounts: Int = 1) throws -> [String]? {
        
        do {
            try rustBackend.initDataDb(dbData: dataDbURL)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw InitializerError.dataDbInitFailed
        }
        
        guard let birthday = WalletBirthday.birthday(with: walletBirthdayHeight) else {
            throw InitializerError.falseStart
        }
        
        self.walletBirthday = birthday
        
        do {
            try rustBackend.initBlocksTable(dbData: dataDbURL, height: Int32(birthday.height), hash: birthday.hash, time: birthday.time, saplingTree: birthday.tree)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw InitializerError.dataDbInitFailed
        }
        
        let downloader = CompactBlockStorage(url: cacheDbURL, readonly: true)
        
        let lastDownloaded = (try? downloader.latestHeight()) ?? ZcashSDK.SAPLING_ACTIVATION_HEIGHT
        // resume from last downloaded block
        lowerBoundHeight = max(birthday.height, lastDownloaded)
        
        guard let accounts = rustBackend.initAccountsTable(dbData: dataDbURL, seed: seedProvider.seed(), accounts: Int32(numberOfAccounts)) else {
            throw rustBackend.lastError() ?? InitializerError.accountInitFailed
        }
        
        return accounts
    }
    
    public func getAddress(index account: Int = 0) -> String? {
        rustBackend.getAddress(dbData: dataDbURL, account: Int32(account))
    }
    
    public func getBalance(account index: Int = 0) -> Int64 {
        rustBackend.getBalance(dbData: dataDbURL, account: Int32(index))
    }
    
    public func getVerifiedBalance(account index: Int = 0) -> Int64 {
        rustBackend.getVerifiedBalance(dbData: dataDbURL, account: Int32(index))
    }
    
    // TODO: make internal
    public func blockProcessor() -> CompactBlockProcessor? {
        var configuration = CompactBlockProcessor.Configuration(cacheDb: cacheDbURL, dataDb: dataDbURL)
        
        configuration.walletBirthday = walletBirthday?.height ?? self.lowerBoundHeight // check if this make sense
           guard let downloader = CompactBlockDownloader.sqlDownloader(service: LightWalletGRPCService(endpoint: endpoint), at: self.cacheDbURL) else {
               return nil
           }
           
           return CompactBlockProcessor(downloader: downloader, backend: self.rustBackend, config: configuration)
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
    var time: UInt32 = 0
    var tree: String = ""
}
