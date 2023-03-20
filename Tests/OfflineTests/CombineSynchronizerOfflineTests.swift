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
    var data: AlternativeSynchronizerAPITestsData!

    var cancellables: [AnyCancellable] = []
    var synchronizerMock: SynchronizerMock!
    var synchronizer: CombineSDKSynchronizer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        data = AlternativeSynchronizerAPITestsData()
        synchronizerMock = SynchronizerMock()
        synchronizer = CombineSDKSynchronizer(synchronizer: synchronizerMock)
        cancellables = []
    }

    override func tearDown() {
        super.tearDown()
        data = nil
    }

    func testStateStreamEmitsAsExpected() {
        let state = SynchronizerState(
            shieldedBalance: WalletBalance(verified: Zatoshi(100), total: Zatoshi(200)),
            transparentBalance: WalletBalance(verified: Zatoshi(200), total: Zatoshi(300)),
            syncStatus: .fetching,
            latestScannedHeight: 111111
        )
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
        let state = SynchronizerState(
            shieldedBalance: WalletBalance(verified: Zatoshi(100), total: Zatoshi(200)),
            transparentBalance: WalletBalance(verified: Zatoshi(200), total: Zatoshi(300)),
            syncStatus: .fetching,
            latestScannedHeight: 111111
        )
        synchronizerMock.underlyingLatestState = state

        XCTAssertEqual(synchronizer.latestState, state)
    }

    func testEventStreamEmitsAsExpected() {
        synchronizerMock.underlyingEventStream = Just(.connectionStateChanged).eraseToAnyPublisher()

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
        synchronizerMock.prepareWithSeedViewingKeysWalletBirthdayClosure = { receivedSeed, receivedViewingKeys, receivedWalletBirthday in
            XCTAssertEqual(receivedSeed, self.data.seed)
            XCTAssertEqual(receivedViewingKeys, [self.data.viewingKey])
            XCTAssertEqual(receivedWalletBirthday, self.data.birthday)
            return .success
        }

        let expectation = XCTestExpectation()

        synchronizer.prepare(with: data.seed, viewingKeys: [data.viewingKey], walletBirthday: data.birthday)
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
        synchronizerMock.prepareWithSeedViewingKeysWalletBirthdayClosure = { _, _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.prepare(with: data.seed, viewingKeys: [data.viewingKey], walletBirthday: data.birthday)
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

        let expectation = XCTestExpectation()

        synchronizer.stop()
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .finished:
                        XCTAssertTrue(stopCalled)
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

        synchronizerMock
            .sendToAddressSpendingKeyZatoshiToAddressMemoClosure = { receivedSpendingKey, receivedZatoshi, receivedToAddress, receivedMemo in
                XCTAssertEqual(receivedSpendingKey, self.data.spendingKey)
                XCTAssertEqual(receivedZatoshi, amount)
                XCTAssertEqual(receivedToAddress, recipient)
                XCTAssertEqual(receivedMemo, memo)
                return self.data.pendingTransactionEntity
            }

        let expectation = XCTestExpectation()

        synchronizer.sendToAddress(spendingKey: data.spendingKey, zatoshi: amount, toAddress: recipient, memo: memo)
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
                    XCTAssertEqual(value.recipient, self.data.pendingTransactionEntity.recipient)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testSendToAddressThrowsError() throws {
        let amount = Zatoshi(100)
        let recipient: Recipient = .transparent(data.transparentAddress)
        let memo: Memo = .text(try MemoText("Some message"))

        synchronizerMock.sendToAddressSpendingKeyZatoshiToAddressMemoClosure = { _, _, _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.sendToAddress(spendingKey: data.spendingKey, zatoshi: amount, toAddress: recipient, memo: memo)
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

        synchronizerMock.shieldFundsSpendingKeyMemoShieldingThresholdClosure = { receivedSpendingKey, receivedMemo, receivedShieldingThreshold in
            XCTAssertEqual(receivedSpendingKey, self.data.spendingKey)
            XCTAssertEqual(receivedMemo, memo)
            XCTAssertEqual(receivedShieldingThreshold, shieldingThreshold)
            return self.data.pendingTransactionEntity
        }

        let expectation = XCTestExpectation()

        synchronizer.shieldFunds(spendingKey: data.spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
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
                    XCTAssertEqual(value.recipient, self.data.pendingTransactionEntity.recipient)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    func testShieldFundsThrowsError() throws {
        let memo: Memo = .text(try MemoText("Some message"))
        let shieldingThreshold = Zatoshi(1)

        synchronizerMock.shieldFundsSpendingKeyMemoShieldingThresholdClosure = { _, _, _ in
            throw "Some error"
        }

        let expectation = XCTestExpectation()

        synchronizer.shieldFunds(spendingKey: data.spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
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

    func testCancelSpendSucceed() {
        synchronizerMock.cancelSpendTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.recipient, self.data.pendingTransactionEntity.recipient)
            return true
        }

        let result = synchronizer.cancelSpend(transaction: data.pendingTransactionEntity)
        XCTAssertTrue(result)
    }

    func testPendingTransactionsSucceed() {
        synchronizerMock.underlyingPendingTransactions = [data.pendingTransactionEntity]
        let transactions = synchronizer.pendingTransactions
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].recipient, self.data.pendingTransactionEntity.recipient)
    }

    func testClearedTransactionsSucceed() {
        synchronizerMock.underlyingClearedTransactions = [data.clearedTransaction]
        let transactions = synchronizer.clearedTransactions
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].id, data.clearedTransaction.id)
    }

    func testSentTransactionsSucceed() {
        synchronizerMock.underlyingSentTransactions = [data.sentTransaction]
        let transactions = synchronizer.sentTransactions
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].id, data.sentTransaction.id)
    }

    func testReceivedTransactionsSucceed() {
        synchronizerMock.underlyingReceivedTransactions = [data.receivedTransaction]
        let transactions = synchronizer.receivedTransactions
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].id, data.receivedTransaction.id)
    }

    func testGetMemosForClearedTransactionSucceed() throws {
        let memo: Memo = .text(try MemoText("Some message"))

        synchronizerMock.getMemosForTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            return [memo]
        }

        let memos = try synchronizer.getMemos(for: data.clearedTransaction)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0], memo)
    }

    func testGetMemosForClearedTransactionThrowsError() {
        synchronizerMock.getMemosForTransactionClosure = { _ in
            throw "Some error"
        }

        do {
            _ = try synchronizer.getMemos(for: data.clearedTransaction)
            XCTFail("Failure is expected")
        } catch { }
    }

    func testGetMemosForReceivedTransactionSucceed() throws {
        let memo: Memo = .text(try MemoText("Some message"))

        synchronizerMock.getMemosForReceivedTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.receivedTransaction.id)
            return [memo]
        }

        let memos = try synchronizer.getMemos(for: data.receivedTransaction)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0], memo)
    }

    func testGetMemosForReceivedTransactionThrowsError() {
        synchronizerMock.getMemosForReceivedTransactionClosure = { _ in
            throw "Some error"
        }

        do {
            _ = try synchronizer.getMemos(for: data.receivedTransaction)
            XCTFail("Failure is expected")
        } catch { }
    }

    func testGetMemosForSentTransactionSucceed() throws {
        let memo: Memo = .text(try MemoText("Some message"))

        synchronizerMock.getMemosForSentTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.sentTransaction.id)
            return [memo]
        }

        let memos = try synchronizer.getMemos(for: data.sentTransaction)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0], memo)
    }

    func testGetMemosForSentTransactionThrowsError() {
        synchronizerMock.getMemosForSentTransactionClosure = { _ in
            throw "Some error"
        }

        do {
            _ = try synchronizer.getMemos(for: data.sentTransaction)
            XCTFail("Failure is expected")
        } catch { }
    }

    func testGetRecipientsForClearedTransaction() {
        let expectedRecipient: TransactionRecipient = .address(.transparent(data.transparentAddress))

        synchronizerMock.getRecipientsForClearedTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            return [expectedRecipient]
        }

        let recipients = synchronizer.getRecipients(for: data.clearedTransaction)

        XCTAssertEqual(recipients.count, 1)
        XCTAssertEqual(recipients[0], expectedRecipient)
    }

    func testGetRecipientsForSentTransaction() {
        let expectedRecipient: TransactionRecipient = .address(.transparent(data.transparentAddress))

        synchronizerMock.getRecipientsForSentTransactionClosure = { receivedTransaction in
            XCTAssertEqual(receivedTransaction.id, self.data.sentTransaction.id)
            return [expectedRecipient]
        }

        let recipients = synchronizer.getRecipients(for: data.sentTransaction)

        XCTAssertEqual(recipients.count, 1)
        XCTAssertEqual(recipients[0], expectedRecipient)
    }

    func testAllConfirmedTransactionsSucceed() throws {
        synchronizerMock.allConfirmedTransactionsFromTransactionClosure = { receivedTransaction, limit in
            XCTAssertEqual(receivedTransaction.id, self.data.clearedTransaction.id)
            XCTAssertEqual(limit, 3)
            return [self.data.clearedTransaction]
        }

        let transactions = try synchronizer.allConfirmedTransactions(from: data.clearedTransaction, limit: 3)

        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].id, data.clearedTransaction.id)
    }

    func testAllConfirmedTransactionsThrowsError() throws {
        synchronizerMock.allConfirmedTransactionsFromTransactionClosure = { _, _ in
            throw "Some error"
        }

        do {
            _ = try synchronizer.allConfirmedTransactions(from: data.clearedTransaction, limit: 3)
            XCTFail("Failure is expected")
        } catch { }
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

        synchronizerMock.refreshUTXOsAddressFromHeightClosure = { receivedAddress, receivedFromHeight in
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
        synchronizerMock.refreshUTXOsAddressFromHeightClosure = { _, _ in
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

    func testGetShieldedBalanceDeprecatedSucceed() {
        synchronizerMock.getShieldedBalanceAccountIndexDeprecatedClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return 333
        }

        XCTAssertEqual(synchronizer.getShieldedBalance(accountIndex: 3), 333)
    }

    func testGetShieldedBalanceSucceed() {
        synchronizerMock.getShieldedBalanceAccountIndexClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return Zatoshi(333)
        }

        XCTAssertEqual(synchronizer.getShieldedBalance(accountIndex: 3), Zatoshi(333))
    }

    func testGetShieldedVerifiedBalanceDeprecatedSucceed() {
        synchronizerMock.getShieldedVerifiedBalanceAccountIndexDeprecatedClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return 333
        }

        XCTAssertEqual(synchronizer.getShieldedVerifiedBalance(accountIndex: 3), 333)
    }

    func testGetShieldedVerifiedBalanceSucceed() {
        synchronizerMock.getShieldedVerifiedBalanceAccountIndexClosure = { receivedAccountIndex in
            XCTAssertEqual(receivedAccountIndex, 3)
            return Zatoshi(333)
        }

        XCTAssertEqual(synchronizer.getShieldedVerifiedBalance(accountIndex: 3), Zatoshi(333))
    }

    func testRewindSucceed() {
        synchronizerMock.rewindPolicyClosure = { receivedPolicy in
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
        synchronizerMock.rewindPolicyClosure = { _ in
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
