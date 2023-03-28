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
    case aliasAlreadyInUse(ZcashSynchronizerAlias)
    case cantUpdateURLWithAlias(URL)
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

/// This identifies different instances of the synchronizer. It is usefull when the client app wants to support multiple wallets (with different
/// seeds) in one app. If the client app support only one wallet then it doesn't have to care about alias atall.
///
/// When custom alias is used to create instance of the synchronizer then paths to all resources (databases, storages...) are updated accordingly to
/// be sure that each instance is using unique paths to resources.
///
/// Custom alias identifiers shouldn't contain any confidential information because it may be logged. It also should have a reasonable length and
/// form. It will be part of the paths to the files (databases, storage...)
///
/// IMPORTANT: Always use `default` alias for one of the instances of the synchronizer.
public enum ZcashSynchronizerAlias: Hashable {
    case `default`
    case custom(String)
}

extension ZcashSynchronizerAlias: CustomStringConvertible {
    public var description: String {
        switch self {
        case .`default`:
            return "default"
        case let .custom(alias):
            return "c_\(alias)"
        }
    }
}

/**
Wrapper for all the Rust backend functionality that does not involve processing blocks. This
class initializes the Rust backend and the supporting data required to exercise those abilities.
The [cash.z.wallet.sdk.block.CompactBlockProcessor] handles all the remaining Rust backend
functionality, related to processing blocks.
*/
// swiftlint:disable type_body_length
public class Initializer {
    struct URLs {
        let fsBlockDbRoot: URL
        let dataDbURL: URL
        let pendingDbURL: URL
        let spendParamsURL: URL
        let outputParamsURL: URL
    }

    public enum InitializationResult {
        case success
        case seedRequired
    }

    // This is used to uniquely identify instance of the SDKSynchronizer. It's used when checking if the Alias is already used or not.
    let id = UUID()

    let rustBackend: ZcashRustBackendWelding.Type
    let alias: ZcashSynchronizerAlias
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
    let logger: Logger

    /// The effective birthday of the wallet based on the height provided when initializing and the checkpoints available on this SDK.
    ///
    /// This contains valid value only after `initialize` function is called.
    private(set) public var walletBirthday: BlockHeight

    /// The purpose of this to migrate from cacheDb to fsBlockDb
    private var cacheDbURL: URL?

    /// Error that can be created when updating URLs according to alias. If this error is created then it is thrown from `SDKSynchronizer.prepare()`
    /// or `SDKSynchronizer.wipe()`.
    var urlsParsingError: InitializerError?

    /// Constructs the Initializer and migrates an old cacheDb to the new file system block cache if a `cacheDbURL` is provided.
    /// - Parameters:
    ///  - cacheDbURL: previous location of the cacheDb. If you don't know what a cacheDb is and you are adopting this SDK for the first time then
    ///                just pass `nil` here.
    ///  - fsBlockDbRoot: location of the compact blocks cache
    ///  - dataDbURL: Location of the data db
    ///  - pendingDbURL: location of the pending transactions database
    ///  - endpoint: the endpoint representing the lightwalletd instance you want to point to
    ///  - spendParamsURL: location of the spend parameters
    ///  - outputParamsURL: location of the output parameters
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
        alias: ZcashSynchronizerAlias = .default,
        logLevel: OSLogger.LogLevel = .debug
    ) {
        let urls = URLs(
            fsBlockDbRoot: fsBlockDbRoot,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL
        )

        // It's not possible to fail from constructor. Technically it's possible but it can be pain for the client apps to handle errors thrown
        // from constructor. So `parsingError` is just stored in initializer and `SDKSynchronizer.prepare()` throw this error if it exists.
        let (updatedURLs, parsingError) = Self.tryToUpdateURLs(with: alias, urls: urls)

        let logger = OSLogger(logLevel: logLevel, alias: alias)
        self.init(
            rustBackend: ZcashRustBackend.self,
            network: network,
            cacheDbURL: cacheDbURL,
            urls: updatedURLs,
            endpoint: endpoint,
            service: Self.makeLightWalletServiceFactory(endpoint: endpoint).make(),
            repository: TransactionRepositoryBuilder.build(dataDbURL: updatedURLs.dataDbURL),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: updatedURLs.dataDbURL,
                readOnly: true,
                caching: true,
                logger: logger
            ),
            storage: FSCompactBlockRepository(
                fsBlockDbRoot: updatedURLs.fsBlockDbRoot,
                metadataStore: .live(
                    fsBlockDbRoot: updatedURLs.fsBlockDbRoot,
                    rustBackend: ZcashRustBackend.self,
                    logger: logger
                ),
                blockDescriptor: .live,
                contentProvider: DirectoryListingProviders.defaultSorted,
                logger: logger
            ),
            saplingParamsSourceURL: saplingParamsSourceURL,
            alias: alias,
            urlsParsingError: parsingError,
            logger: logger
        )
    }

    /// Internal for dependency injection purposes.
    ///
    /// !!! It's expected that URLs put here are already update with the Alias.
    init(
        rustBackend: ZcashRustBackendWelding.Type,
        network: ZcashNetwork,
        cacheDbURL: URL?,
        urls: URLs,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        accountRepository: AccountRepository,
        storage: CompactBlockRepository,
        saplingParamsSourceURL: SaplingParamsSourceURL,
        alias: ZcashSynchronizerAlias,
        urlsParsingError: InitializerError?,
        logger: Logger
    ) {
        self.cacheDbURL = cacheDbURL
        self.rustBackend = rustBackend
        self.fsBlockDbRoot = urls.fsBlockDbRoot
        self.dataDbURL = urls.dataDbURL
        self.pendingDbURL = urls.pendingDbURL
        self.endpoint = endpoint
        self.spendParamsURL = urls.spendParamsURL
        self.outputParamsURL = urls.outputParamsURL
        self.saplingParamsSourceURL = saplingParamsSourceURL
        self.alias = alias
        self.lightWalletService = service
        self.transactionRepository = repository
        self.accountRepository = accountRepository
        self.storage = storage
        self.blockDownloaderService = BlockDownloaderServiceImpl(service: service, storage: storage)
        self.network = network
        self.walletBirthday = Checkpoint.birthday(with: 0, network: network).height
        self.urlsParsingError = urlsParsingError
        self.logger = logger
    }

    private static func makeLightWalletServiceFactory(endpoint: LightWalletEndpoint) -> LightWalletServiceFactory {
        return LightWalletServiceFactory(endpoint: endpoint)
    }

    /// Try to update URLs with `alias`.
    ///
    /// If the `default` alias is used then the URLs are changed at all.
    /// If the `custom("anotherInstance")` is used then last path component or the URL is updated like this:
    /// - /some/path/to.file -> /some/path/c_anotherInstance_to.file
    /// - /some/path/to/directory -> /some/path/to/c_anotherInstance_directory
    ///
    /// If any of the URLs can't be parsed then returned error isn't nil.
    private static func tryToUpdateURLs(
        with alias: ZcashSynchronizerAlias,
        urls: URLs
    ) -> (URLs, InitializerError?) {
        let updatedURLsResult = Self.updateURLs(with: alias, urls: urls)

        let parsingError: InitializerError?
        let updatedURLs: URLs
        switch updatedURLsResult {
        case let .success(updated):
            parsingError = nil
            updatedURLs = updated
        case let .failure(error):
            parsingError = error
            // When failure happens just use original URLs because something must be used. But this shouldn't be a problem because
            // `SDKSynchronizer.prepare()` handles this error. And the SDK won't work if it isn't switched from `unprepared` state.
            updatedURLs = urls
        }

        return (updatedURLs, parsingError)
    }

    private static func updateURLs(
        with alias: ZcashSynchronizerAlias,
        urls: URLs
    ) -> Result<URLs, InitializerError> {
        guard let updatedFsBlockDbRoot = urls.fsBlockDbRoot.updateLastPathComponent(with: alias) else {
            return .failure(.cantUpdateURLWithAlias(urls.fsBlockDbRoot))
        }

        guard let updatedDataDbURL = urls.dataDbURL.updateLastPathComponent(with: alias) else {
            return .failure(.cantUpdateURLWithAlias(urls.dataDbURL))
        }

        guard let updatedPendingDbURL = urls.pendingDbURL.updateLastPathComponent(with: alias) else {
            return .failure(.cantUpdateURLWithAlias(urls.pendingDbURL))
        }

        guard let updatedSpendParamsURL = urls.spendParamsURL.updateLastPathComponent(with: alias) else {
            return .failure(.cantUpdateURLWithAlias(urls.spendParamsURL))
        }

        guard let updateOutputParamsURL = urls.outputParamsURL.updateLastPathComponent(with: alias) else {
            return .failure(.cantUpdateURLWithAlias(urls.outputParamsURL))
        }

        return .success(
            URLs(
                fsBlockDbRoot: updatedFsBlockDbRoot,
                dataDbURL: updatedDataDbURL,
                pendingDbURL: updatedPendingDbURL,
                spendParamsURL: updatedSpendParamsURL,
                outputParamsURL: updateOutputParamsURL
            )
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
            networkType: self.network.networkType,
            logger: logger
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
        case let .aliasAlreadyInUse(alias):
            return """
            The Alias \(alias) used for this instance of the SDKSynchronizer is already in use. Each instance of the SDKSynchronizer must use unique \
            Alias.
            """
        case .cantUpdateURLWithAlias(let url):
            return "Can't update path URL with alias. \(url)"
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
