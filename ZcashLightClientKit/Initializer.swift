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
    case invalidViewingKey(key: String)
}

/**
 Represents a lightwallet instance endpoint to connect to
 */
public struct LightWalletEndpoint {
    public var host: String
    public var port: Int
    public var secure: Bool
    public var timeout: TimeInterval
    
/**
     initializes a LightWalletEndpoint
     - Parameters:
        - address: a String containing the host address
        - port: string with the port of the host address
        - secure: true if connecting through TLS. Default value is true
     */
    public init(address: String, port: Int, secure: Bool = true, timeout: TimeInterval = 10) {
        self.host = address
        self.port = port
        self.secure = secure
        self.timeout = timeout
    }
}

/**
 Wrapper for all the Rust backend functionality that does not involve processing blocks. This
 class initializes the Rust backend and the supporting data required to exercise those abilities.
 The [cash.z.wallet.sdk.block.CompactBlockProcessor] handles all the remaining Rust backend
 functionality, related to processing blocks.
 */
public class Initializer {
    
    private(set) var rustBackend: ZcashRustBackendWelding.Type
    private(set) var alias: String
    private(set) var endpoint: LightWalletEndpoint
    
    private var lowerBoundHeight: BlockHeight
    private(set) var cacheDbURL: URL
    private(set) var dataDbURL: URL
    private(set) var pendingDbURL: URL
    private(set) var spendParamsURL: URL
    private(set) var outputParamsURL: URL
    private(set) var lightWalletService: LightWalletService
    private(set) var transactionRepository: TransactionRepository
    private(set) var downloader: CompactBlockDownloader
    private(set) var processor: CompactBlockProcessor?

    /**
     Constructs the Initializer
     - Parameters:
        - cacheDbURL: location of the compact blocks cache db
        - dataDbURL: Location of the data db
        - pendingDbURL: location of the pending transactions database
        - endpoint: the endpoint representing the lightwalletd instance you want to point to
        - spendParamsURL: location of the spend parameters
        - outputParamsURL: location of the output parameters
     */
    convenience public init (cacheDbURL: URL,
                 dataDbURL: URL,
                 pendingDbURL: URL,
                 endpoint: LightWalletEndpoint,
                 spendParamsURL: URL,
                 outputParamsURL: URL,
                 alias: String = "",
                 loggerProxy: Logger? = nil) {
        
        let storage = CompactBlockStorage(url: cacheDbURL, readonly: false)
        try? storage.createTable()
        
        let lwdService = LightWalletGRPCService(endpoint: endpoint)
        
        self.init(rustBackend: ZcashRustBackend.self,
                  lowerBoundHeight: ZcashSDK.SAPLING_ACTIVATION_HEIGHT,
                  cacheDbURL: cacheDbURL,
                  dataDbURL: dataDbURL,
                  pendingDbURL: pendingDbURL,
                  endpoint: endpoint,
                  service: lwdService,
                  repository: TransactionRepositoryBuilder.build(dataDbURL: dataDbURL),
                  downloader: CompactBlockDownloader(service: lwdService, storage: storage),
                  spendParamsURL: spendParamsURL,
                  outputParamsURL: outputParamsURL,
                  alias: alias,
                  loggerProxy: loggerProxy
        )
    }
    
    /**
        internal for dependency injection purposes
     */
    init(rustBackend: ZcashRustBackendWelding.Type,
         lowerBoundHeight: BlockHeight,
         cacheDbURL: URL,
         dataDbURL: URL,
         pendingDbURL: URL,
         endpoint: LightWalletEndpoint,
         service: LightWalletService,
         repository: TransactionRepository,
         downloader: CompactBlockDownloader,
         spendParamsURL: URL,
         outputParamsURL: URL,
         alias: String = "",
         loggerProxy: Logger? = nil
         
    ) {
        logger = loggerProxy
        self.rustBackend = rustBackend
        self.lowerBoundHeight = lowerBoundHeight
        self.cacheDbURL = cacheDbURL
        self.dataDbURL = dataDbURL
        self.pendingDbURL = pendingDbURL
        self.endpoint = endpoint
        self.spendParamsURL = spendParamsURL
        self.outputParamsURL = outputParamsURL
        self.alias = alias
        self.lightWalletService = service
        self.transactionRepository = repository
        self.downloader = downloader
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
     - Parameters:
       - viewingKeys: Extended Full Viewing Keys to initialize the DBs with
     */
    
    public func initialize(viewingKeys: [String], walletBirthday: BlockHeight) throws {
        let derivationTool = DerivationTool()
        for vk in viewingKeys {
            do {
                try derivationTool.validateViewingKey(viewingKey: vk)
            } catch {
                throw InitializerError.invalidViewingKey(key: vk)
            }
        }
        
        do {
            try rustBackend.initDataDb(dbData: dataDbURL)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw InitializerError.dataDbInitFailed
        }
        
        let birthday = WalletBirthday.birthday(with: walletBirthday)
        
        do {
            try rustBackend.initBlocksTable(dbData: dataDbURL, height: Int32(birthday.height), hash: birthday.hash, time: birthday.time, saplingTree: birthday.tree)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw InitializerError.dataDbInitFailed
        }
        
        let lastDownloaded = (try? downloader.storage.latestHeight()) ?? birthday.height
        // resume from last downloaded block
        lowerBoundHeight = max(birthday.height, lastDownloaded)
        
        let config = CompactBlockProcessor.Configuration(cacheDb: cacheDbURL,
                                                         dataDb: dataDbURL,
                                                         walletBirthday: birthday.height)
        
        self.processor = CompactBlockProcessorBuilder.buildProcessor(configuration: config,
                                                                     downloader: self.downloader,
                                                                     transactionRepository: transactionRepository,
                                                                     backend: rustBackend)
        
        do {
            guard try rustBackend.initAccountsTable(dbData: dataDbURL, exfvks: viewingKeys) else {
                throw rustBackend.lastError() ?? InitializerError.accountInitFailed
            }
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        }catch {
            throw rustBackend.lastError() ?? InitializerError.accountInitFailed
        }
        
    }
    
    /**
     get address from the given account index
     - Parameter account:  the index of the account
     */
    public func getAddress(index account: Int = 0) -> String? {
        rustBackend.getAddress(dbData: dataDbURL, account: Int32(account))
    }
    /**
     get (unverified) balance from the given account index
     - Parameter account: the index of the account
     */
    public func getBalance(account index: Int = 0) -> Int64 {
        rustBackend.getBalance(dbData: dataDbURL, account: Int32(index))
    }
    
    /**
    get verified balance from the given account index
    - Parameter account: the index of the account
    */
    public func getVerifiedBalance(account index: Int = 0) -> Int64 {
        rustBackend.getVerifiedBalance(dbData: dataDbURL, account: Int32(index))
    }
    
    /**
     checks if the provided address is a valid shielded zAddress
     */
    public func isValidShieldedAddress(_ address: String) -> Bool {
        (try? rustBackend.isValidShieldedAddress(address)) ?? false
    }
    /**
     checks if the provided address is a transparent zAddress
     */
    public func isValidTransparentAddress(_ address: String) -> Bool {
        (try? rustBackend.isValidTransparentAddress(address)) ?? false
    }
    
    /**
     underlying CompactBlockProcessor for this initializer
     
     Although it is recommended to always use the higher abstraction first, if you need a more fine grained control over synchronization, you can use a CompactBlockProcessor instead of a Synchronizer.
     
     */
    public func blockProcessor() -> CompactBlockProcessor? {
        self.processor
    }
    
    func isSpendParameterPresent() -> Bool {
        FileManager.default.isReadableFile(atPath: self.spendParamsURL.path)
    }
    
    func isOutputParameterPresent() -> Bool {
        FileManager.default.isReadableFile(atPath: self.outputParamsURL.path)
    }
    
    func downloadParametersIfNeeded(result: @escaping (Result<Bool,Error>) -> Void)  {
        let spendParameterPresent = isSpendParameterPresent()
        let outputParameterPresent = isOutputParameterPresent()
        
        if spendParameterPresent && outputParameterPresent {
            result(.success(true))
            return
        }
        
        let outputURL = self.outputParamsURL
        let spendURL = self.spendParamsURL
        
        if !outputParameterPresent {
            SaplingParameterDownloader.downloadOutputParameter(outputURL) { outputResult in
                switch outputResult {
                case .failure(let e):
                    result(.failure(e))
                case .success:
                    guard !spendParameterPresent else {
                        result(.success(false))
                        return
                    }
                    SaplingParameterDownloader.downloadSpendParameter(spendURL) { (spendResult) in
                        switch spendResult {
                        case .failure(let e):
                            result(.failure(e))
                        case .success:
                            result(.success(false))
                        }
                    }
                }
            }
        } else if !spendParameterPresent {
            SaplingParameterDownloader.downloadSpendParameter(spendURL) { (spendResult) in
                switch spendResult {
                case .failure(let e):
                    result(.failure(e))
                case .success:
                    result(.success(false))
                }
            }
        }
    }
}

class CompactBlockProcessorBuilder {
    static func buildProcessor(configuration: CompactBlockProcessor.Configuration,
                               downloader: CompactBlockDownloader,
                               transactionRepository: TransactionRepository,
                               backend: ZcashRustBackendWelding.Type) -> CompactBlockProcessor {
        return CompactBlockProcessor(downloader: downloader,
                                     backend: backend,
                                     config: configuration,
                                     repository: transactionRepository)
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
 
 - Parameters:
    - height: the height at the time the wallet was born
    -  hash: the block hash corresponding to the given height
    -  time: the time the wallet was born, in seconds
    -  tree: the sapling tree corresponding to the given height. This takes around 15 minutes of processing to
 generate from scratch because all blocks since activation need to be considered. So when it is calculated in
 advance it can save the user a lot of time.
 */
public struct WalletBirthday {
   public private(set) var height: BlockHeight = -1
   public private(set) var hash: String = ""
   public private(set) var time: UInt32 = 0
   public private(set) var tree: String = ""
}
