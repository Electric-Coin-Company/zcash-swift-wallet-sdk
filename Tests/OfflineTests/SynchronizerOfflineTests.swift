//
//  SynchronizerOfflineTests.swift
//  
//
//  Created by Michal Fousek on 23.03.2023.
//

import Combine
import Foundation
@testable import TestUtils
import XCTest
@testable import ZcashLightClientKit

class SynchronizerOfflineTests: ZcashTestCase {
    let data = TestsData(networkType: .testnet)
    var network: ZcashNetwork!
    var cancellables: [AnyCancellable] = []

    override func setUp() async throws {
        try await super.setUp()
        network = ZcashNetworkBuilder.network(for: .testnet)
        cancellables = []
    }

    override func tearDown() async throws {
        try await super.tearDown()
        network = nil
        cancellables = []
    }

    func testCallPrepareWithAlreadyUsedAliasThrowsError() async throws {
        let firstTestCoordinator = try await TestCoordinator(
            alias: .custom("alias"),
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        let secondTestCoordinator = try await TestCoordinator(
            alias: .custom("alias"),
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await firstTestCoordinator.prepare(seed: Environment.seedBytes)
        } catch {
            XCTFail("Unpected fail. Prepare should succeed. \(error)")
        }

        do {
            _ = try await secondTestCoordinator.prepare(seed: Environment.seedBytes)
            XCTFail("Prepare should fail.")
        } catch { }
    }

    func testWhenSynchronizerIsDeallocatedAliasIsntUsedAnymore() async throws {
        var testCoordinator: TestCoordinator! = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await testCoordinator.prepare(seed: Environment.seedBytes)
        } catch {
            XCTFail("Unpected fail. Prepare should succeed. \(error)")
        }

        testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await testCoordinator.prepare(seed: Environment.seedBytes)
        } catch {
            XCTFail("Unpected fail. Prepare should succeed. \(error)")
        }
    }

    func testCallWipeWithAlreadyUsedAliasThrowsError() async throws {
        let firstTestCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        let secondTestCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        let firstWipeExpectation = XCTestExpectation(description: "First wipe expectation")

        firstTestCoordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        firstWipeExpectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected error when calling wipe \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        await fulfillment(of: [firstWipeExpectation], timeout: 1)

        let secondWipeExpectation = XCTestExpectation(description: "Second wipe expectation")

        secondTestCoordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Second wipe should fail with error.")
                    case let .failure(error):
                        if let error = error as? ZcashError, case .initializerAliasAlreadyInUse = error {
                            secondWipeExpectation.fulfill()
                        } else {
                            XCTFail("Wipe failed with unexpected error: \(error)")
                        }
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        await fulfillment(of: [secondWipeExpectation], timeout: 1)
    }

    func testPrepareCanBeCalledAfterWipeWithSameInstanceOfSDKSynchronizer() async throws {
        let testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        let expectation = XCTestExpectation(description: "Wipe expectation")

        testCoordinator.synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected error when calling wipe \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1)

        do {
            _ = try await testCoordinator.prepare(seed: Environment.seedBytes)
        } catch {
            XCTFail("Prepare after wipe should succeed.")
        }
    }

    func testSendToAddressCalledWithoutPrepareThrowsError() async throws {
        let testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await testCoordinator.synchronizer.sendToAddress(
                spendingKey: testCoordinator.spendingKey,
                zatoshi: Zatoshi(1),
                toAddress: .transparent(data.transparentAddress),
                memo: nil
            )
            XCTFail("Send to address should fail.")
        } catch {
            if let error = error as? ZcashError, case .synchronizerNotPrepared = error {
            } else {
                XCTFail("Send to address failed with unexpected error: \(error)")
            }
        }
    }

    func testShieldFundsCalledWithoutPrepareThrowsError() async throws {
        let testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await testCoordinator.synchronizer.shieldFunds(
                spendingKey: testCoordinator.spendingKey,
                memo: Memo(string: "memo"),
                shieldingThreshold: Zatoshi(1)
            )
            XCTFail("Shield funds should fail.")
        } catch {
            if let error = error as? ZcashError, case .synchronizerNotPrepared = error {
            } else {
                XCTFail("Shield funds failed with unexpected error: \(error)")
            }
        }
    }

    func testRefreshUTXOCalledWithoutPrepareThrowsError() async throws {
        let testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        do {
            _ = try await testCoordinator.synchronizer.refreshUTXOs(address: data.transparentAddress, from: 1)
            XCTFail("Shield funds should fail.")
        } catch {
            if let error = error as? ZcashError, case .synchronizerNotPrepared = error {
            } else {
                XCTFail("Shield funds failed with unexpected error: \(error)")
            }
        }
    }

    func testRewindCalledWithoutPrepareThrowsError() async throws {
        let testCoordinator = try await TestCoordinator(
            alias: .default,
            container: mockContainer,
            walletBirthday: 10,
            network: network,
            callPrepareInConstructor: false
        )

        let expectation = XCTestExpectation()

        testCoordinator.synchronizer.rewind(.quick)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Rewind should fail with error.")
                    case let .failure(error):
                        if let error = error as? ZcashError, case .synchronizerNotPrepared = error {
                            expectation.fulfill()
                        } else {
                            XCTFail("Rewind failed with unexpected error: \(error)")
                        }
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testURLsParsingFailsInInitializerPrepareThenThrowsError() async throws {
        let validFileURL = URL(fileURLWithPath: "/some/valid/path/to.file")
        let validDirectoryURL = URL(fileURLWithPath: "/some/valid/path/to/directory")
        let invalidPathURL = URL(string: "https://whatever")!

        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: validDirectoryURL,
            generalStorageURL: validDirectoryURL,
            dataDbURL: invalidPathURL,
            endpoint: LightWalletEndpointBuilder.default,
            network: ZcashNetworkBuilder.network(for: .testnet),
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            saplingParamsSourceURL: .default,
            alias: .default,
            loggingPolicy: .default(.debug)
        )

        XCTAssertNotNil(initializer.urlsParsingError)

        let synchronizer = SDKSynchronizer(initializer: initializer)

        do {
            _ = try await synchronizer.prepare(with: Environment.seedBytes, walletBirthday: 123000)
            XCTFail("Failure of prepare is expected.")
        } catch {
            if let error = error as? ZcashError, case let .initializerCantUpdateURLWithAlias(failedURL) = error {
                XCTAssertEqual(failedURL, invalidPathURL)
            } else {
                XCTFail("Failed with unexpected error: \(error)")
            }
        }
    }

    func testURLsParsingFailsInInitializerWipeThenThrowsError() async throws {
        let validFileURL = URL(fileURLWithPath: "/some/valid/path/to.file")
        let validDirectoryURL = URL(fileURLWithPath: "/some/valid/path/to/directory")
        let invalidPathURL = URL(string: "https://whatever")!

        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: validDirectoryURL,
            generalStorageURL: validDirectoryURL,
            dataDbURL: invalidPathURL,
            endpoint: LightWalletEndpointBuilder.default,
            network: ZcashNetworkBuilder.network(for: .testnet),
            spendParamsURL: validFileURL,
            outputParamsURL: validFileURL,
            saplingParamsSourceURL: .default,
            alias: .default,
            loggingPolicy: .default(.debug)
        )

        XCTAssertNotNil(initializer.urlsParsingError)

        let synchronizer = SDKSynchronizer(initializer: initializer)
        let expectation = XCTestExpectation()

        synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Failure of wipe is expected.")
                    case let .failure(error):
                        if let error = error as? ZcashError, case let .initializerCantUpdateURLWithAlias(failedURL) = error {
                            XCTAssertEqual(failedURL, invalidPathURL)
                            expectation.fulfill()
                        } else {
                            XCTFail("Failed with unexpected error: \(error)")
                        }
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testIsNewSessionOnUnpreparedToValidTransition() {
        XCTAssertTrue(SessionTicker.live.isNewSyncSession(.unprepared, .syncing(0)))
    }

    func testIsNotNewSessionOnUnpreparedToStateThatWontSync() {
        XCTAssertFalse(SessionTicker.live.isNewSyncSession(.unprepared, .disconnected))
        XCTAssertFalse(SessionTicker.live.isNewSyncSession(.unprepared, .unprepared))
    }

    func testIsNotNewSessionOnUnpreparedToInvalidOrUnexpectedTransitions() {
        XCTAssertFalse(SessionTicker.live.isNewSyncSession(.unprepared, .synced))
    }

    func testIsNotNewSyncSessionOnSameSession() {
        XCTAssertFalse(
            SessionTicker.live.isNewSyncSession(
                .syncing(
                    0.5
                ),
                .syncing(
                    0.6
                )
            )
        )
    }

    func testIsNewSyncSessionWhenStartingFromSynced() {
        XCTAssertTrue(
            SessionTicker.live.isNewSyncSession(
                .synced,
                .syncing(
                    0.6
                )
            )
        )
    }

    func testIsNewSyncSessionWhenStartingFromDisconnected() {
        XCTAssertTrue(
            SessionTicker.live.isNewSyncSession(
                .disconnected,
                .syncing(
                    0.6
                )
            )
        )
    }

    func testIsNewSyncSessionWhenStartingFromStopped() {
        XCTAssertTrue(
            SessionTicker.live.isNewSyncSession(
                .stopped,
                .syncing(
                    0.6
                )
            )
        )
    }

    func testInternalSyncStatusesDontDifferWhenOuterStatusIsTheSame() {
        XCTAssertFalse(InternalSyncStatus.disconnected.isDifferent(from: .disconnected))
        XCTAssertFalse(InternalSyncStatus.syncing(0).isDifferent(from: .syncing(0)))
        XCTAssertFalse(InternalSyncStatus.stopped.isDifferent(from: .stopped))
        XCTAssertFalse(InternalSyncStatus.synced.isDifferent(from: .synced))
        XCTAssertFalse(InternalSyncStatus.unprepared.isDifferent(from: .unprepared))
    }
    
    func testInternalSyncStatusMap_SyncingLowerBound() {
        let synchronizerState = synchronizerState(
            for:
                InternalSyncStatus.syncing(0)
        )

        if case let .syncing(data) = synchronizerState.syncStatus, data != nextafter(0.0, data) {
            XCTFail("Syncing is expected to be 0% (0.0) but received \(data).")
        }
    }

    func testInternalSyncStatusMap_SyncingInTheMiddle() {
        let synchronizerState = synchronizerState(
            for:
                InternalSyncStatus.syncing(0.45)
        )

        if case let .syncing(data) = synchronizerState.syncStatus, data != nextafter(0.45, data) {
            XCTFail("Syncing is expected to be 45% (0.45) but received \(data).")
        }
    }

    func testInternalSyncStatusMap_SyncingUpperBound() {
        let synchronizerState = synchronizerState(
            for:
                InternalSyncStatus.syncing(0.9)
        )

        if case let .syncing(data) = synchronizerState.syncStatus, data != nextafter(0.9, data) {
            XCTFail("Syncing is expected to be 90% (0.9) but received \(data).")
        }
    }
    
    func testInternalSyncStatusMap_FetchingUpperBound() {
        let synchronizerState = synchronizerState(for: InternalSyncStatus.syncing(1))

        if case let .syncing(data) = synchronizerState.syncStatus, data != nextafter(1.0, data) {
            XCTFail("Syncing is expected to be 100% (1.0) but received \(data).")
        }
    }

    func testLinearIsSetAsDefault() async throws {
        let databases = TemporaryDbBuilder.build()
        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: databases.fsCacheDbRoot,
            generalStorageURL: testGeneralStorageDirectory,
            dataDbURL: databases.dataDB,
            endpoint: LightWalletEndpoint(address: "lightwalletd.electriccoin.co", port: 9067, secure: true),
            network: ZcashNetworkBuilder.network(for: .mainnet),
            spendParamsURL: try __spendParamsURL(),
            outputParamsURL: try __outputParamsURL(),
            saplingParamsSourceURL: SaplingParamsSourceURL.tests,
            alias: .default,
            loggingPolicy: .default(.debug)
        )
        
        XCTAssertTrue(initializer.syncAlgorithm == .linear, "Spend before Sync is a beta feature so linear syncing is set to default.")
    }
    
    func synchronizerState(for internalSyncStatus: InternalSyncStatus) -> SynchronizerState {
        SynchronizerState(
            syncSessionID: .nullID,
            shieldedBalance: .zero,
            transparentBalance: .zero,
            internalSyncStatus: internalSyncStatus,
            latestScannedHeight: .zero,
            latestBlockHeight: .zero,
            latestScannedTime: 0
        )
    }
}
