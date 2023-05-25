//
//  MigrateLegacyCacheDBActionTests.swift
//  
//
//  Created by Lukáš Korba on 23.05.2023.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

final class MigrateLegacyCacheDBActionTests: ZcashTestCase {
    var underlyingAlias: ZcashSynchronizerAlias?
    var underlyingCacheDbURL: URL?
    var underlyingFsBlockCacheRoot: URL?

    override func setUp() {
        super.setUp()
        
        underlyingAlias = nil
        underlyingCacheDbURL = nil
        underlyingFsBlockCacheRoot = nil
    }
    
    func testMigrateLegacyCacheDBAction_noCacheDbURL() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            let nextContext = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
            
            XCTAssertFalse(compactBlockRepositoryMock.createCalled, "storage.create() is not expected to be called.")
            XCTAssertFalse(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is not expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validateServer,
                "nextContext after .migrateLegacyCacheDB is expected to be .validateServer but received \(nextState)"
            )
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_noCacheDbURL is not expected to fail. \(error)")
        }
    }
    
    func testMigrateLegacyCacheDBAction_noFsBlockCacheRoot() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        underlyingCacheDbURL = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).fsCacheURL

        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            _ = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
            XCTFail("testMigrateLegacyCacheDBAction_noFsBlockCacheRoot is expected to fail.")
        } catch ZcashError.compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL {
            XCTAssertFalse(compactBlockRepositoryMock.createCalled, "storage.create() is not expected to be called.")
            XCTAssertFalse(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is not expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is not expected to be called.")
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_noFsBlockCacheRoot is expected to fail with ZcashError.compactBlockProcessorCacheDbMigrationFsCacheMigrationFailedSameURL but received \(error)")
        }
    }
    
    func testMigrateLegacyCacheDBAction_aliasDoesntMatchDefault() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        // any valid URL needed...
        underlyingCacheDbURL = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).fsCacheURL
        underlyingFsBlockCacheRoot = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).dataDbURL
        
        underlyingAlias = .custom("any")

        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            let nextContext = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
            
            XCTAssertFalse(compactBlockRepositoryMock.createCalled, "storage.create() is not expected to be called.")
            XCTAssertFalse(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is not expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is not expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validateServer,
                "nextContext after .migrateLegacyCacheDB is expected to be .validateServer but received \(nextState)"
            )
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_aliasDoesntMatchDefault is not expected to fail. \(error)")
        }
    }
    
    func testMigrateLegacyCacheDBAction_isNotReadableFile() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        // any valid URL needed...
        underlyingCacheDbURL = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).fsCacheURL
        underlyingFsBlockCacheRoot = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).dataDbURL
        
        zcashFileManagerMock.isReadableFileAtPathReturnValue = false
        
        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            let nextContext = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
            
            XCTAssertFalse(compactBlockRepositoryMock.createCalled, "storage.create() is not expected to be called.")
            XCTAssertFalse(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is not expected to be called.")
            XCTAssertTrue(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is expected to be called.")
            XCTAssertFalse(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is not expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is not expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validateServer,
                "nextContext after .migrateLegacyCacheDB is expected to be .validateServer but received \(nextState)"
            )
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_isNotReadableFile is not expected to fail. \(error)")
        }
    }
    
    func testMigrateLegacyCacheDBAction_removeItemFailed() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        // any valid URL needed...
        underlyingCacheDbURL = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).fsCacheURL
        underlyingFsBlockCacheRoot = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).dataDbURL
        
        zcashFileManagerMock.isReadableFileAtPathReturnValue = true
        zcashFileManagerMock.removeItemAtClosure = { _ in throw "remove failed" }
        
        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            _ = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
        } catch ZcashError.compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb {
            XCTAssertFalse(compactBlockRepositoryMock.createCalled, "storage.create() is not expected to be called.")
            XCTAssertFalse(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is not expected to be called.")
            XCTAssertTrue(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is expected to be called.")
            XCTAssertTrue(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is expected to be called.")
            XCTAssertFalse(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is not expected to be called.")
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_removeItemFailed is expected to fail with ZcashError.compactBlockProcessorCacheDbMigrationFailedToDeleteLegacyDb but received \(error)")
        }
    }
    
    func testMigrateLegacyCacheDBAction_nextAction() async throws {
        let compactBlockRepositoryMock = CompactBlockRepositoryMock()
        let transactionRepositoryMock = TransactionRepositoryMock()
        let zcashFileManagerMock = ZcashFileManagerMock()
        let internalSyncProgressStorageMock = InternalSyncProgressStorageMock()

        // any valid URL needed...
        underlyingCacheDbURL = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).fsCacheURL
        underlyingFsBlockCacheRoot = DefaultResourceProvider(network: ZcashNetworkBuilder.network(for: .testnet)).dataDbURL
        
        zcashFileManagerMock.isReadableFileAtPathReturnValue = true
        zcashFileManagerMock.removeItemAtClosure = { _ in }
        compactBlockRepositoryMock.createClosure = { }
        transactionRepositoryMock.lastScannedHeightReturnValue = 1
        internalSyncProgressStorageMock.setForClosure = { _, _ in }
        
        let migrateLegacyCacheDBAction = setupAction(
            compactBlockRepositoryMock,
            transactionRepositoryMock,
            zcashFileManagerMock,
            internalSyncProgressStorageMock
        )

        do {
            let nextContext = try await migrateLegacyCacheDBAction.run(with: .init(state: .migrateLegacyCacheDB)) { _ in }
            
            XCTAssertTrue(compactBlockRepositoryMock.createCalled, "storage.create() is expected to be called.")
            XCTAssertTrue(transactionRepositoryMock.lastScannedHeightCalled, "transactionRepository.lastScannedHeight() is expected to be called.")
            XCTAssertTrue(zcashFileManagerMock.isReadableFileAtPathCalled, "fileManager.isReadableFile() is expected to be called.")
            XCTAssertTrue(zcashFileManagerMock.removeItemAtCalled, "fileManager.removeItem() is expected to be called.")
            XCTAssertTrue(internalSyncProgressStorageMock.setForCalled, "internalSyncProgress.set() is expected to be called.")

            let nextState = await nextContext.state
            XCTAssertTrue(
                nextState == .validateServer,
                "nextContext after .migrateLegacyCacheDB is expected to be .validateServer but received \(nextState)"
            )
        } catch {
            XCTFail("testMigrateLegacyCacheDBAction_aliasDoesntMatchDefault is not expected to fail. \(error)")
        }
    }

    private func setupAction(
        _ compactBlockRepositoryMock: CompactBlockRepositoryMock = CompactBlockRepositoryMock(),
        _ transactionRepositoryMock: TransactionRepositoryMock = TransactionRepositoryMock(),
        _ zcashFileManagerMock: ZcashFileManagerMock = ZcashFileManagerMock(),
        _ internalSyncProgressStorageMock: InternalSyncProgressStorageMock = InternalSyncProgressStorageMock(),
        _ loggerMock: LoggerMock = LoggerMock()
    ) -> MigrateLegacyCacheDBAction {
        mockContainer.register(type: InternalSyncProgress.self, isSingleton: true) { _ in
            InternalSyncProgress(alias: .default, storage: internalSyncProgressStorageMock, logger: loggerMock)
        }
        mockContainer.mock(type: CompactBlockRepository.self, isSingleton: true) { _ in compactBlockRepositoryMock }
        mockContainer.mock(type: TransactionRepository.self, isSingleton: true) { _ in transactionRepositoryMock }
        mockContainer.mock(type: ZcashFileManager.self, isSingleton: true) { _ in zcashFileManagerMock }
        mockContainer.mock(type: Logger.self, isSingleton: true) { _ in loggerMock }
        
        return MigrateLegacyCacheDBAction(
            container: mockContainer,
            configProvider: setupConfig()
        )
    }
    
    private func setupConfig() -> CompactBlockProcessor.ConfigProvider {
        let defaultConfig = CompactBlockProcessor.Configuration.standard(
            for: ZcashNetworkBuilder.network(for: .testnet), walletBirthday: 0
        )
        
        let config = CompactBlockProcessor.Configuration(
            alias: underlyingAlias ?? defaultConfig.alias,
            cacheDbURL: underlyingCacheDbURL ?? defaultConfig.cacheDbURL,
            fsBlockCacheRoot: underlyingFsBlockCacheRoot ?? defaultConfig.fsBlockCacheRoot,
            dataDb: defaultConfig.dataDb,
            spendParamsURL: defaultConfig.spendParamsURL,
            outputParamsURL: defaultConfig.outputParamsURL,
            saplingParamsSourceURL: defaultConfig.saplingParamsSourceURL,
            walletBirthdayProvider: defaultConfig.walletBirthdayProvider,
            saplingActivation: defaultConfig.saplingActivation,
            network: defaultConfig.network
        )

        return CompactBlockProcessor.ConfigProvider(config: config)
    }
}
