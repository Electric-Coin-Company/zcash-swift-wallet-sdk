//
//  CombineSynchronizerOfflineTests.swift
//  
//
//  Created by Michal Fousek on 20.03.2023.
//

import Combine
import Foundation
@testable import TestUtils
import XCTest
@testable import ZcashLightClientKit

class CombineSynchronizerOfflineTests: XCTestCase {
    var data: TestsData!

    var cancellables: [AnyCancellable] = []
    var synchronizerMock: SynchronizerMock!
    var synchronizer: CombineSDKSynchronizer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        data = TestsData(networkType: .testnet)
        synchronizerMock = SynchronizerMock()
        synchronizer = CombineSDKSynchronizer(synchronizer: synchronizerMock)
        cancellables = []
    }

    override func tearDown() {
        super.tearDown()
        data = nil
    }

    func testAliasIsAsExpected() {
        synchronizerMock.underlyingAlias = .custom("some_alias")
        XCTAssertEqual(synchronizer.alias, .custom("some_alias"))
    }

    func testStateStreamEmitsAsExpected() {
        let state = SynchronizerState.mock
        synchronizerMock.underlyingStateStream = Just(state).eraseToAnyPublisher()

        let expectation = XCTestExpectation()

        synchronizer.stateStream
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected failure with error: \(error)")
                    }
                },
                receiveValue: { receivedState in
                    XCTAssertEqual(receivedState, state)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testLatestStateIsAsExpected() {
        let state = SynchronizerState.mock
        synchronizerMock.underlyingLatestState = state

        XCTAssertEqual(synchronizer.latestState, state)
    }

    func testEventStreamEmitsAsExpected() {
        synchronizerMock.underlyingEventStream = Just(.connectionStateChanged(.connecting)).eraseToAnyPublisher()

        let expectation = XCTestExpectation()

        synchronizer.eventStream
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected failure with error: \(error)")
                    }
                },
                receiveValue: { event in
                    if case .connectionStateChanged = event {
                    } else {
                        XCTFail("Unexpected event: \(event)")
                    }
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testConnectionStateAsExpected() {
        synchronizerMock.underlyingConnectionState = .reconnecting
        XCTAssertEqual(synchronizer.connectionState, .reconnecting)
    }

    func testPrepareSucceed() throws {
        let mockedViewingKey = self.data.viewingKey
        synchronizerMock.prepareWithWalletBirthdayClosure = { receivedSeed, receivedWalletBirthday in
            XCTAssertEqual(receivedSeed, self.data.seed)
            XCTAssertEqual(receivedWalletBirthday, self.data.birthday)
            return .success
        }

        let expectation = XCTestExpectation()

        synchronizer.prepare(with: data.seed, walletBirthday: data.birthday)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, .success)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testPrepareThrowsError() throws {
        let mockedViewingKey = self.data.viewingKey
        synchronizerMock.prepareWithWalletBirthdayClosure = { _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.prepare(with: data.seed, walletBirthday: data.birthday)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testStartSucceeds() {
        synchronizerMock.startRetryClosure = { retry in
            XCTAssertTrue(retry)
            return
        }

        let expectation = XCTestExpectation()

        synchronizer.start(retry: true)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testStartThrowsError() {
        synchronizerMock.startRetryClosure = { _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.start(retry: true)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testStopSucceed() {
        var stopCalled = false
        synchronizerMock.stopClosure = {
            stopCalled = true
        }
        
        synchronizer.stop()
        XCTAssertTrue(stopCalled)
    }

    func testGetSaplingAddressSucceed() {
        synchronizerMock.getSaplingAddressAccountIndexClosure = { accountIndex in
            XCTAssertEqual(accountIndex, 3)
            return self.data.saplingAddress
        }

        let expectation = XCTestExpectation()

        synchronizer.getSaplingAddress(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, self.data.saplingAddress)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetUnifiedAddressSucceed() {
        synchronizerMock.getUnifiedAddressAccountIndexClosure = { accountIndex in
            XCTAssertEqual(accountIndex, 3)
            return self.data.unifiedAddress
        }

        let expectation = XCTestExpectation()

        synchronizer.getUnifiedAddress(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, self.data.unifiedAddress)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetTransparentAddressSucceed() {
        synchronizerMock.getTransparentAddressAccountIndexClosure = { accountIndex in
            XCTAssertEqual(accountIndex, 3)
            return self.data.transparentAddress
        }

        let expectation = XCTestExpectation()

        synchronizer.getTransparentAddress(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, self.data.transparentAddress)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testSendToAddressSucceed() throws {
        let amount = Zatoshi(100)
        let recipient: Recipient = .transparent(data.transparentAddress)
        let memo: Memo = .text(try MemoText("Some message"))
        let mockedSpendingKey = data.spendingKey

        synchronizerMock
            .sendToAddressSpendingKeyZatoshiToAddressMemoClosure = { receivedSpendingKey, receivedZatoshi, receivedToAddress, receivedMemo in
                XCTAssertEqual(receivedSpendingKey, mockedSpendingKey)
                XCTAssertEqual(receivedZatoshi, amount)
                XCTAssertEqual(receivedToAddress, recipient)
                XCTAssertEqual(receivedMemo, memo)
                return self.data.pendingTransactionEntity
            }

        let expectation = XCTestExpectation()

        synchronizer.sendToAddress(spendingKey: mockedSpendingKey, zatoshi: amount, toAddress: recipient, memo: memo)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.value, self.data.pendingTransactionEntity.value)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testSendToAddressThrowsError() throws {
        let amount = Zatoshi(100)
        let recipient: Recipient = .transparent(data.transparentAddress)
        let memo: Memo = .text(try MemoText("Some message"))
        let mockedSpendingKey = data.spendingKey

        synchronizerMock.sendToAddressSpendingKeyZatoshiToAddressMemoClosure = { _, _, _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.sendToAddress(spendingKey: mockedSpendingKey, zatoshi: amount, toAddress: recipient, memo: memo)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testShieldFundsSucceed() throws {
        let memo: Memo = .text(try MemoText("Some message"))
        let shieldingThreshold = Zatoshi(1)
        let mockedSpendingKey = data.spendingKey

        synchronizerMock.shieldFundsSpendingKeyMemoShieldingThresholdClosure = { receivedSpendingKey, receivedMemo, receivedShieldingThreshold in
            XCTAssertEqual(receivedSpendingKey, mockedSpendingKey)
            XCTAssertEqual(receivedMemo, memo)
            XCTAssertEqual(receivedShieldingThreshold, shieldingThreshold)
            return self.data.pendingTransactionEntity
        }

        let expectation = XCTestExpectation()

        synchronizer.shieldFunds(spendingKey: mockedSpendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.id, self.data.pendingTransactionEntity.id)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testShieldFundsThrowsError() throws {
        let memo: Memo = .text(try MemoText("Some message"))
        let shieldingThreshold = Zatoshi(1)
        let mockedSpendingKey = data.spendingKey

        synchronizerMock.shieldFundsSpendingKeyMemoShieldingThresholdClosure = { _, _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.shieldFunds(spendingKey: mockedSpendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testClearedTransactionsSucceed() {
        synchronizerMock.underlyingTransactions = [data.clearedTransaction]

        let expectation = XCTestExpectation()

        synchronizer.allTransactions
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.map { $0.id }, [self.data.clearedTransaction.id])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testSentTransactionsSucceed() {
        synchronizerMock.underlyingSentTransactions = [data.sentTransaction]

        let expectation = XCTestExpectation()

        synchronizer.sentTransactions
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.map { $0.id }, [self.data.sentTransaction.id])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testReceivedTransactionsSucceed() {
        synchronizerMock.underlyingReceivedTransactions = [data.receivedTransaction]

        let expectation = XCTestExpectation()

        synchronizer.receivedTransactions
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.map { $0.id }, [self.data.receivedTransaction.id])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetMemosForClearedTransactionSucceed() throws {
        let memo: Memo = .text(try MemoText("Some message"))

        synchronizerMock.getMemosForClearedTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            return [memo]
        }

        let expectation = XCTestExpectation()

        synchronizer.getMemos(for: data.clearedTransaction)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, [memo])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetMemosForClearedTransactionThrowsError() {
        synchronizerMock.getMemosForClearedTransactionClosure = { _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.getMemos(for: data.clearedTransaction)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetRecipientsForClearedTransaction() {
        let expectedRecipient = TransactionRecipient.address(.transparent(self.data.transparentAddress))

        synchronizerMock.getRecipientsForClearedTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            return [expectedRecipient]
        }

        let expectation = XCTestExpectation()

        synchronizer.getRecipients(for: data.clearedTransaction)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, [expectedRecipient])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testAllConfirmedTransactionsSucceed() throws {
        synchronizerMock.allTransactionsFromLimitClosure = { receivedTransaction, limit in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            XCTAssertEqual(limit, 3)
            return [self.data.clearedTransaction]
        }

        let expectation = XCTestExpectation()

        synchronizer.allTransactions(from: data.clearedTransaction, limit: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.map { $0.id }, [self.data.clearedTransaction.id])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testAllConfirmedTransactionsThrowsError() throws {
        synchronizerMock.allTransactionsFromLimitClosure = { _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.allTransactions(from: data.clearedTransaction, limit: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testLatestHeightSucceed() {
        synchronizerMock.latestHeightClosure = { 123000 }

        let expectation = XCTestExpectation()

        synchronizer.latestHeight()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, 123000)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testLatestHeightThrowsError() {
        synchronizerMock.latestHeightClosure = {
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.latestHeight()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testRefreshUTXOsSucceed() {
        let insertedEntity = UnspentTransactionOutputEntityMock(address: "addr", txid: Data(), index: 0, script: Data(), valueZat: 1, height: 2)
        let skippedEntity = UnspentTransactionOutputEntityMock(address: "addr2", txid: Data(), index: 1, script: Data(), valueZat: 2, height: 3)
        let refreshedUTXO = (inserted: [insertedEntity], skipped: [skippedEntity])

        synchronizerMock.refreshUTXOsAddressFromClosure = { receivedAddress, receivedFromHeight in
            XCTAssertEqual(receivedAddress, self.data.transparentAddress)
            XCTAssertEqual(receivedFromHeight, 121000)
            return refreshedUTXO
        }

        let expectation = XCTestExpectation()

        synchronizer.refreshUTXOs(address: data.transparentAddress, from: 121000)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value.inserted as! [UnspentTransactionOutputEntityMock], [insertedEntity])
                    XCTAssertEqual(value.skipped as! [UnspentTransactionOutputEntityMock], [skippedEntity])
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testRefreshUTXOsThrowsError() {
        synchronizerMock.refreshUTXOsAddressFromClosure = { _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.refreshUTXOs(address: data.transparentAddress, from: 121000)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetTransparentBalanceSucceed() {
        let expectedWalletBalance = WalletBalance(verified: Zatoshi(100), total: Zatoshi(200))

        synchronizerMock.getTransparentBalanceAccountIndexClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return expectedWalletBalance
        }

        let expectation = XCTestExpectation()

        synchronizer.getTransparentBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, expectedWalletBalance)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetTransparentBalanceThrowsError() {
        synchronizerMock.getTransparentBalanceAccountIndexClosure = { _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.getTransparentBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetShieldedBalanceSucceed() {
        synchronizerMock.getShieldedBalanceAccountIndexClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return Zatoshi(333)
        }

        let expectation = XCTestExpectation()

        synchronizer.getShieldedBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, Zatoshi(333))
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetShieldedBalanceThrowsError() {
        synchronizerMock.getShieldedBalanceAccountIndexClosure = { _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.getShieldedBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetShieldedVerifiedBalanceSucceed() {
        synchronizerMock.getShieldedVerifiedBalanceAccountIndexClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return Zatoshi(333)
        }

        let expectation = XCTestExpectation()

        synchronizer.getShieldedVerifiedBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unpected failure with error: \(error)")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, Zatoshi(333))
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testGetShieldedVerifiedBalanceThrowsError() {
        synchronizerMock.getShieldedVerifiedBalanceAccountIndexClosure = { _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.getShieldedVerifiedBalance(accountIndex: 3)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Error should be thrown.")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("No value is expected")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testRewindSucceed() {
        synchronizerMock.rewindClosure = { receivedPolicy in
            if case .quick = receivedPolicy {
            } else {
                XCTFail("Unexpected policy \(receivedPolicy)")
            }

            return Empty().eraseToAnyPublisher()
        }

        let expectation = XCTestExpectation()

        synchronizer.rewind(.quick)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected failure \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testRewindThrowsError() {
        synchronizerMock.rewindClosure = { _ in
            return Fail(error: "some error").eraseToAnyPublisher()
        }

        let expectation = XCTestExpectation()

        synchronizer.rewind(.quick)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Failure is expected")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testWipeSucceed() {
        synchronizerMock.wipeClosure = {
            return Empty().eraseToAnyPublisher()
        }

        let expectation = XCTestExpectation()

        synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        expectation.fulfill()
                    case let .failure(error):
                        XCTFail("Unexpected failure \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testWipeThrowsError() {
        synchronizerMock.wipeClosure = {
            return Fail(error: "some error").eraseToAnyPublisher()
        }

        let expectation = XCTestExpectation()

        synchronizer.wipe()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTFail("Failure is expected")
                    case .failure:
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }
}
