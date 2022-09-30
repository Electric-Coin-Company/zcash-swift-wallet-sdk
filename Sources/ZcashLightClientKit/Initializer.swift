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
    private(set) var accountRepository: AccountRepository
    private(set) var storage: CompactBlockStorage
    private(set) var downloader: CompactBlockDownloader
    private(set) var network: ZcashNetwork
    private(set) public var viewingKeys: [UnifiedFullViewingKey]
    /// The effective birthday of the wallet based on the height provided when initializing
    /// and the checkpoints available on this SDK
    private(set) public var walletBirthday: BlockHeight

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
    convenience public init (
        cacheDbURL: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        network: ZcashNetwork,
        spendParamsURL: URL,
        outputParamsURL: URL,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
        alias: String = "",
        loggerProxy: Logger? = nil
    ) {
        let lwdService = LightWalletGRPCService(endpoint: endpoint)
        
        self.init(
            rustBackend: ZcashRustBackend.self,
            lowerBoundHeight: walletBirthday,
            network: network,
            cacheDbURL: cacheDbURL,
            dataDbURL: dataDbURL,
            pendingDbURL: pendingDbURL,
            endpoint: endpoint,
            service: lwdService,
            repository: TransactionRepositoryBuilder.build(dataDbURL: dataDbURL),
            accountRepository: AccountRepositoryBuilder.build(
                dataDbURL: dataDbURL,
                readOnly: true,
                caching: true
            ),
            storage: CompactBlockStorage(url: cacheDbURL, readonly: false),
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            viewingKeys: viewingKeys,
            walletBirthday: walletBirthday,
            alias: alias,
            loggerProxy: loggerProxy
        )
    }
    
    /**
    Internal for dependency injection purposes
    */
    init(
        rustBackend: ZcashRustBackendWelding.Type,
        lowerBoundHeight: BlockHeight,
        network: ZcashNetwork,
        cacheDbURL: URL,
        dataDbURL: URL,
        pendingDbURL: URL,
        endpoint: LightWalletEndpoint,
        service: LightWalletService,
        repository: TransactionRepository,
        accountRepository: AccountRepository,
        storage: CompactBlockStorage,
        spendParamsURL: URL,
        outputParamsURL: URL,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight,
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
        self.accountRepository = accountRepository
        self.storage = storage
        self.downloader = CompactBlockDownloader(service: service, storage: storage)
        self.viewingKeys = viewingKeys
        self.walletBirthday = walletBirthday
        self.network = network
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
    public func initialize(with seed: [UInt8]?) throws -> InitializationResult {
        do {
            try storage.createTable()
        } catch {
            throw InitializerError.cacheDbInitFailed
        }
        
        do {
            if case .seedRequired = try rustBackend.initDataDb(dbData: dataDbURL, seed: seed, networkType: network.networkType) {
                return .seedRequired
            }
        } catch {
            throw InitializerError.dataDbInitFailed
        }

        let checkpoint = Checkpoint.birthday(with: self.walletBirthday, network: network)
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
            throw InitializerError.dataDbInitFailed
        }
        self.walletBirthday = checkpoint.height
        
        let lastDownloaded = (try? downloader.storage.latestHeight()) ?? walletBirthday
        // resume from last downloaded block
        lowerBoundHeight = max(walletBirthday, lastDownloaded)
 
        do {
            guard try rustBackend.initAccountsTable(
                dbData: dataDbURL,
                ufvks: viewingKeys,
                networkType: network.networkType
            ) else {
                throw rustBackend.lastError() ?? InitializerError.accountInitFailed
            }
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch RustWeldingError.malformedStringInput {
            throw RustWeldingError.malformedStringInput
        } catch {
            throw rustBackend.lastError() ?? InitializerError.accountInitFailed
        }

        return .success
    }

    /// get (unverified) balance from the given account index
    /// - Parameter account: the index of the account
    @available(*, deprecated, message: "This function will be removed soon. Use the function returning `Zatoshi` instead")
    public func getBalance(account index: Int = 0) -> Int64 {
        rustBackend.getBalance(dbData: dataDbURL, account: Int32(index), networkType: network.networkType)
    }


    /// get (unverified) balance from the given account index
    /// - Parameter account: the index of the account
    /// - Returns: balance in `Zatoshi`
    public func getBalance(account index: Int = 0) -> Zatoshi {
        Zatoshi(
            rustBackend.getBalance(
                dbData: dataDbURL,
                account: Int32(index),
                networkType: network.networkType
            )
        )
    }

    /// get verified balance from the given account index
    /// - Parameter account: the index of the account
    @available(*, deprecated, message: "This function will be removed soon. Use the one returning `Zatoshi` instead")
    public func getVerifiedBalance(account index: Int = 0) -> Int64 {
        rustBackend.getVerifiedBalance(dbData: dataDbURL, account: Int32(index), networkType: network.networkType)
    }

    /// get verified balance from the given account index
    /// - Parameter account: the index of the account
    /// - Returns: balance in `Zatoshi`
    public func getVerifiedBalance(account index: Int = 0) -> Zatoshi {
        Zatoshi(
            rustBackend.getVerifiedBalance(
                dbData: dataDbURL,
                account: Int32(index),
                networkType: network.networkType
            )
        )
    }
    
    /**
    checks if the provided address is a valid sapling address
    */
    public func isValidSaplingAddress(_ address: String) -> Bool {
        (try? rustBackend.isValidSaplingAddress(address, networkType: network.networkType)) ?? false
    }

    /**
    checks if the provided address is a transparent zAddress
    */
    public func isValidTransparentAddress(_ address: String) -> Bool {
        (try? rustBackend.isValidTransparentAddress(address, networkType: network.networkType)) ?? false
    }
    
    func isSpendParameterPresent() -> Bool {
        FileManager.default.isReadableFile(atPath: self.spendParamsURL.path)
    }
    
    func isOutputParameterPresent() -> Bool {
        FileManager.default.isReadableFile(atPath: self.outputParamsURL.path)
    }
    
    @discardableResult
    func downloadParametersIfNeeded() async throws -> Bool {
        let spendParameterPresent = isSpendParameterPresent()
        let outputParameterPresent = isOutputParameterPresent()
        
        if spendParameterPresent && outputParameterPresent {
            return true
        }
        
        let outputURL = self.outputParamsURL
        let spendURL = self.spendParamsURL
        
        do {
            if !outputParameterPresent && !spendParameterPresent {
                async let outputURLRequest = SaplingParameterDownloader.downloadOutputParameter(outputURL)
                async let spendURLRequest = SaplingParameterDownloader.downloadSpendParameter(spendURL)
                _ = try await [outputURLRequest, spendURLRequest]
                return false
            } else if !outputParameterPresent {
                try await SaplingParameterDownloader.downloadOutputParameter(outputURL)
                return false
            } else if !spendParameterPresent {
                try await SaplingParameterDownloader.downloadSpendParameter(spendURL)
                return false
            }
        } catch {
            throw error
        }
        return true
    }
}

enum CompactBlockProcessorBuilder {
    // swiftlint:disable:next function_parameter_count
    static func buildProcessor(
        configuration: CompactBlockProcessor.Configuration,
        service: LightWalletService,
        storage: CompactBlockStorage,
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        backend: ZcashRustBackendWelding.Type
    ) -> CompactBlockProcessor {
        return CompactBlockProcessor(
            service: service,
            storage: storage,
            backend: backend,
            config: configuration,
            repository: transactionRepository,
            accountRepository: accountRepository
        )
    }
}
