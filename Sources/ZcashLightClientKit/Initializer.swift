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
    case fsCacheInitFailed(Error)
    case dataDbInitFailed(Error)
    case accountInitFailed(Error)
    case invalidViewingKey(key: String)
}

/**
Represents a lightwallet instance endpoint to connect to
*/
public struct LightWalletEndpoint {
    public var host: String
    public var port: Int
    public var secure: Bool
    public var singleCallTimeoutInMillis: Int64
    public var streamingCallTimeoutInMillis: Int64
    
    /**
    initializes a LightWalletEndpoint
    - Parameters:
        - address: a String containing the host address
        - port: string with the port of the host address
        - secure: true if connecting through TLS. Default value is true
        - singleCallTimeoutInMillis: timeout for single calls in Milliseconds. Default 30 seconds
        - streamingCallTimeoutInMillis: timeout for streaming calls in Milliseconds. Default 100 seconds
    */
    public init(
        address: String,
        port: Int,
        secure: Bool = true,
        singleCallTimeoutInMillis: Int64 = 30000,
        streamingCallTimeoutInMillis: Int64 = 100000
    ) {
        self.host = address
        self.port = port
        self.secure = secure
        self.singleCallTimeoutInMillis = singleCallTimeoutInMillis
        self.streamingCallTimeoutInMillis = streamingCallTimeoutInMillis
    }
}

extension Notification.Name {
    static let connectionStatusChanged = Notification.Name("LightWalletServiceConnectivityStatusChanged")
}

/// This contains URLs from which can the SDK fetch files that contain sapling parameters.
/// Use `SaplingParamsSourceURL.default` when initilizing the SDK.
public struct SaplingParamsSourceURL {
    public let spendParamFileURL: URL
    public let outputParamFileURL: URL

    public static var `default`: SaplingParamsSourceURL {
        return SaplingParamsSourceURL(spendParamFileURL: ZcashSDK.spendParamFileURL, outputParamFileURL: ZcashSDK.outputParamFileURL)
    }
}

/**
Wrapper for all the Rust backend functionality that does not involve processing blocks. This
class initializes the Rust backend and the supporting data required to exercise those abilities.
The [cash.z.wallet.sdk.block.CompactBlockProcessor] handles all the remaining Rust backend
functionality, related to processing blocks.
*/
public class Initializer {
    public enum InitializationResult {
        case success
        case seedRequired
    }

    let rustBackend: ZcashRustBackendWelding.Type
    let alias: String
    let endpoint: LightWalletEndpoint
    let fsBlockDbRoot: URL
    let dataDbURL: URL
    let pendingDbURL: URL
    let spendParamsURL: URL
    let outputParamsURL: URL
    let saplingParamsSourceURL: SaplingParamsSourceURL
    let lightWalletService: LightWalletService
    let transactionRepository: TransactionRepository
    let accountRepository: AccountRepository
    let storage: CompactBlockRepository
    let blockDownloaderService: BlockDownloaderService
    let network: ZcashNetwork

    /// The effective birthday of the wallet based on the height provided when initializing and the checkpoints available on this SDK.
    ///
    /// This contains valid value only after `initialize` function is called.
    private(set) public var walletBirthday: BlockHeight

    /// The purpose of this to migrate from cacheDb to fsBlockDb
    private var cacheDbURL: URL?

    /// Constructs the Initializer
    /// - Parameters:
    ///  - fsBlockDbRoot: location of the compact blocks cache
    ///  - dataDbURL: Location of the data db
    ///  - pendingDbURL: location of the pending transactions database
    ///  - endpoint: the endpoint representing the lightwalletd instance you want to point to
    ///  - spendParamsURL: location of the spend parameters
    ///  - outputParamsURL: location of the output parameters
    convenience public init (
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        network: ZcashNetwork,
        spendParamsURL: URL,
        outputParamsURL: URL,
        saplingParamsSourceURL: SaplingParamsSourceURL,
        alias: String = "",
        loggerProxy: Logger? = nil
    ) {
        self.init(
            rustBackend: ZcashRustBackend.self,
            network: network,
            cacheDbURL: nil,
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: Self.makeLightWalletServiceFactory(endpoint: endpoint).make(),
            repository: TransactionRepositoryBuilder.build(dataDbURL: dataDbURL),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: dataDbURL,
                readOnly: true,
                caching: true
            ),
            storage: FSCompactBlockRepository(
                fsBlockDbRoot: fsBlockDbRoot,
                metadataStore: .live(
                    fsBlockDbRoot: fsBlockDbRoot,
                    rustBackend: ZcashRustBackend.self
                ),
                blockDescriptor: .live,
                contentProvider: DirectoryListingProviders.defaultSorted
            ),
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: saplingParamsSourceURL,
            alias: alias,
            loggerProxy: loggerProxy
        )
    }

    /// Constructs the Initializer and migrates an old cacheDb to the new file system block cache if
    /// a `cacheDbURL` is provided.
    /// - Parameters:
    ///  - cacheDbURL: previous location of the cacheDb. Use this constru
    ///  - fsBlockDbRoot: location of the compact blocks cache
    ///  - dataDbURL: Location of the data db
    ///  - pendingDbURL: location of the pending transactions database
    ///  - endpoint: the endpoint representing the lightwalletd instance you want to point to
    ///  - spendParamsURL: location of the spend parameters
    ///  - outputParamsURL: location of the output parameters
    ///
    /// - note: If you don't know what a cacheDb is and you are adopting
    /// this SDK for the first time then you just need to invoke `convenience init(fsBlockDbRoot: URL, dataDbURL: URL, pendingDbURL: URL, endpoint: LightWalletEndpoint, network: ZcashNetwork, spendParamsURL: URL, outputParamsURL: URL, alias: String = "", loggerProxy: Logger? = nil)` instead
    convenience public init (
        cacheDbURL: URL?,
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        network: ZcashNetwork,
        spendParamsURL: URL,
        outputParamsURL: URL,
        saplingParamsSourceURL: SaplingParamsSourceURL,
        alias: String = "",
        loggerProxy: Logger? = nil
    ) {
        self.init(
            rustBackend: ZcashRustBackend.self,
            network: network,
            cacheDbURL: cacheDbURL,
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: Self.makeLightWalletServiceFactory(endpoint: endpoint).make(),
            repository: TransactionRepositoryBuilder.build(dataDbURL: dataDbURL),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: dataDbURL,
                readOnly: true,
                caching: true
            ),
            storage: FSCompactBlockRepository(
                fsBlockDbRoot: fsBlockDbRoot,
                metadataStore: .live(
                    fsBlockDbRoot: fsBlockDbRoot,
                    rustBackend: ZcashRustBackend.self
                ),
                blockDescriptor: .live,
                contentProvider: DirectoryListingProviders.defaultSorted
            ),
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: saplingParamsSourceURL,
            alias: alias,
            loggerProxy: loggerProxy
        )
    }

    /**
    Internal for dependency injection purposes
    */
    init(
        rustBackend: ZcashRustBackendWelding.Type,
        network: ZcashNetwork,
        cacheDbURL: URL?,
        fsBlockDbRoot: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        accountRepository: AccountRepository,
        storage: CompactBlockRepository,
        spendParamsURL: URL,
        outputParamsURL: URL,
        saplingParamsSourceURL: SaplingParamsSourceURL,
        alias: String = "",
        loggerProxy: Logger? = nil
    ) {
        logger = loggerProxy
        self.cacheDbURL = cacheDbURL
        self.rustBackend = rustBackend
        self.fsBlockDbRoot = fsBlockDbRoot
        self.dataDbURL = dataDbURL
        self.pendingDbURL = pendingDbURL
        self.endpoint = endpoint
        self.spendParamsURL = spendParamsURL
        self.outputParamsURL = outputParamsURL
        self.saplingParamsSourceURL = saplingParamsSourceURL
        self.alias = alias
        self.lightWalletService = service
        self.transactionRepository = repository
        self.accountRepository = accountRepository
        self.storage = storage
        self.blockDownloaderService = BlockDownloaderServiceImpl(service: service, storage: storage)
        self.network = network
        self.walletBirthday = Checkpoint.birthday(with: 0, network: network).height
    }

    private static func makeLightWalletServiceFactory(endpoint: LightWalletEndpoint) -> LightWalletServiceFactory {
        return LightWalletServiceFactory(
            endpoint: endpoint,
            connectionStateChange: { oldState, newState in
                NotificationSender.default.post(
                    name: .synchronizerConnectionStateChanged,
                    object: self,
                    userInfo: [
                        SDKSynchronizer.NotificationKeys.previousConnectionState: oldState,
                        SDKSynchronizer.NotificationKeys.currentConnectionState: newState
                    ]
                )
            }
        )
    }

    /// Initialize the wallet. The ZIP-32 seed bytes can optionally be passed to perform
    /// database migrations. most of the times the seed won't be needed. If they do and are
    /// not provided this will fail with `InitializationResult.seedRequired`. It could
    /// be the case that this method is invoked by a wallet that does not contain the seed phrase
    /// and is view-only, or by a wallet that does have the seed but the process does not have the
    /// consent of the OS to fetch the keys from the secure storage, like on background tasks.
    ///
    /// 'cache.db' and 'data.db' files are created by this function (if they
    /// do not already exist). These files can be given a prefix for scenarios where multiple wallets
    ///
    /// - Parameter seed: ZIP-32 Seed bytes for the wallet that will be initialized
    /// - Throws: `InitializerError.dataDbInitFailed` if the creation of the dataDb fails
    /// `InitializerError.accountInitFailed` if the account table can't be initialized. 
    func initialize(with seed: [UInt8]?, viewingKeys: [UnifiedFullViewingKey], walletBirthday: BlockHeight) throws -> InitializationResult {
        do {
            try storage.create()
        } catch {
            throw InitializerError.fsCacheInitFailed(error)
        }
        
        do {
            if case .seedRequired = try rustBackend.initDataDb(dbData: dataDbURL, seed: seed, networkType: network.networkType) {
                return .seedRequired
            }
        } catch {
            throw InitializerError.dataDbInitFailed(error)
        }

        let checkpoint = Checkpoint.birthday(with: walletBirthday, network: network)
        do {
            try rustBackend.initBlocksTable(
                dbData: dataDbURL,
                height: Int32(checkpoint.height),
                hash: checkpoint.hash,
                time: checkpoint.time,
                saplingTree: checkpoint.saplingTree,
                networkType: network.networkType
            )
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw InitializerError.dataDbInitFailed(error)
        }

        self.walletBirthday = checkpoint.height
 
        do {
            try rustBackend.initAccountsTable(
                dbData: dataDbURL,
                ufvks: viewingKeys,
                networkType: network.networkType
            )
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch RustWeldingError.malformedStringInput {
            throw RustWeldingError.malformedStringInput
        } catch {
            throw InitializerError.accountInitFailed(error)
        }

        let migrationManager = MigrationManager(
            pendingDbConnection: SimpleConnectionProvider(path: pendingDbURL.path),
            networkType: self.network.networkType
        )

        try migrationManager.performMigration()

        return .success
    }

    /// get (unverified) balance from the given account index
    /// - Parameter account: the index of the account
    @available(*, deprecated, message: "This function will be removed soon. Use the function returning `Zatoshi` instead")
    public func getBalance(account index: Int = 0) -> Int64 {
        guard let balance = try? rustBackend.getBalance(dbData: dataDbURL, account: Int32(index), networkType: network.networkType) else { return 0 }

        return balance
    }

    /// get (unverified) balance from the given account index
    /// - Parameter account: the index of the account
    /// - Returns: balance in `Zatoshi`
    public func getBalance(account index: Int = 0) -> Zatoshi {
        guard let balance = try? rustBackend.getBalance(
            dbData: dataDbURL,
            account: Int32(index),
            networkType: network.networkType
        ) else {
            return .zero
        }

        return Zatoshi(balance)
    }

    /// get verified balance from the given account index
    /// - Parameter account: the index of the account
    @available(*, deprecated, message: "This function will be removed soon. Use the one returning `Zatoshi` instead")
    public func getVerifiedBalance(account index: Int = 0) -> Int64 {
        guard let balance = try? rustBackend.getVerifiedBalance(dbData: dataDbURL, account: Int32(index), networkType: network.networkType) else {
            return 0
        }

        return balance
    }

    /// get verified balance from the given account index
    /// - Parameter account: the index of the account
    /// - Returns: balance in `Zatoshi`
    public func getVerifiedBalance(account index: Int = 0) -> Zatoshi {
        guard let balance = try? rustBackend.getVerifiedBalance(
            dbData: dataDbURL,
            account: Int32(index),
            networkType: network.networkType
        ) else { return .zero }

        return Zatoshi(balance)
    }
    
    /**
    checks if the provided address is a valid sapling address
    */
    public func isValidSaplingAddress(_ address: String) -> Bool {
        rustBackend.isValidSaplingAddress(address, networkType: network.networkType)
    }

    /**
    checks if the provided address is a transparent zAddress
    */
    public func isValidTransparentAddress(_ address: String) -> Bool {
        rustBackend.isValidTransparentAddress(address, networkType: network.networkType)
    }
}

extension InitializerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidViewingKey:
            return "The provided viewing key is invalid"
        case .dataDbInitFailed(let error):
            return "dataDb init failed with error: \(error.localizedDescription)"
        case .accountInitFailed(let error):
            return "account table init failed with error: \(error.localizedDescription)"
        case .fsCacheInitFailed(let error):
            return "Compact Block Cache failed to initialize with error: \(error.localizedDescription)"
        }
    }
}

/// Synchronous helpers that support clients that don't use structured concurrency yet
extension Initializer {
    func getCurrentAddress(accountIndex: Int) -> UnifiedAddress? {
        try? self.rustBackend.getCurrentAddress(
            dbData: self.dataDbURL,
            account: Int32(accountIndex),
            networkType: self.network.networkType
        )
    }
}
