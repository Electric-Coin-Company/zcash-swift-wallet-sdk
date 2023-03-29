// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import Combine
@testable import ZcashLightClientKit



// MARK: - AutoMockable protocols
class SynchronizerMock: Synchronizer {


    init(
    ) {
    }
    var alias: ZcashSynchronizerAlias {
        get { return underlyingAlias }
    }
    var underlyingAlias: ZcashSynchronizerAlias!
    var latestState: SynchronizerState {
        get { return underlyingLatestState }
    }
    var underlyingLatestState: SynchronizerState!
    var connectionState: ConnectionState {
        get { return underlyingConnectionState }
    }
    var underlyingConnectionState: ConnectionState!
    var stateStream: AnyPublisher<SynchronizerState, Never> {
        get { return underlyingStateStream }
    }
    var underlyingStateStream: AnyPublisher<SynchronizerState, Never>!
    var eventStream: AnyPublisher<SynchronizerEvent, Never> {
        get { return underlyingEventStream }
    }
    var underlyingEventStream: AnyPublisher<SynchronizerEvent, Never>!
    var metrics: SDKMetrics {
        get { return underlyingMetrics }
    }
    var underlyingMetrics: SDKMetrics!
    var pendingTransactions: [PendingTransactionEntity] {
        get async { return underlyingPendingTransactions }
    }
    var underlyingPendingTransactions: [PendingTransactionEntity] = []
    var clearedTransactions: [ZcashTransaction.Overview] {
        get async { return underlyingClearedTransactions }
    }
    var underlyingClearedTransactions: [ZcashTransaction.Overview] = []
    var sentTransactions: [ZcashTransaction.Sent] {
        get async { return underlyingSentTransactions }
    }
    var underlyingSentTransactions: [ZcashTransaction.Sent] = []
    var receivedTransactions: [ZcashTransaction.Received] {
        get async { return underlyingReceivedTransactions }
    }
    var underlyingReceivedTransactions: [ZcashTransaction.Received] = []

    // MARK: - prepare

    var prepareWithViewingKeysWalletBirthdayThrowableError: Error?
    var prepareWithViewingKeysWalletBirthdayCallsCount = 0
    var prepareWithViewingKeysWalletBirthdayCalled: Bool {
        return prepareWithViewingKeysWalletBirthdayCallsCount > 0
    }
    var prepareWithViewingKeysWalletBirthdayReceivedArguments: (seed: [UInt8]?, viewingKeys: [UnifiedFullViewingKey], walletBirthday: BlockHeight)?
    var prepareWithViewingKeysWalletBirthdayReturnValue: Initializer.InitializationResult!
    var prepareWithViewingKeysWalletBirthdayClosure: (([UInt8]?, [UnifiedFullViewingKey], BlockHeight) async throws -> Initializer.InitializationResult)?

    func prepare(with seed: [UInt8]?, viewingKeys: [UnifiedFullViewingKey], walletBirthday: BlockHeight) async throws -> Initializer.InitializationResult {
        if let error = prepareWithViewingKeysWalletBirthdayThrowableError {
            throw error
        }
        prepareWithViewingKeysWalletBirthdayCallsCount += 1
        prepareWithViewingKeysWalletBirthdayReceivedArguments = (seed: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
        if let closure = prepareWithViewingKeysWalletBirthdayClosure {
            return try await closure(seed, viewingKeys, walletBirthday)
        } else {
            return prepareWithViewingKeysWalletBirthdayReturnValue
        }
    }

    // MARK: - start

    var startRetryThrowableError: Error?
    var startRetryCallsCount = 0
    var startRetryCalled: Bool {
        return startRetryCallsCount > 0
    }
    var startRetryReceivedRetry: Bool?
    var startRetryClosure: ((Bool) async throws -> Void)?

    func start(retry: Bool) async throws {
        if let error = startRetryThrowableError {
            throw error
        }
        startRetryCallsCount += 1
        startRetryReceivedRetry = retry
        try await startRetryClosure?(retry)
    }

    // MARK: - stop

    var stopCallsCount = 0
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCount += 1
        stopClosure?()
    }

    // MARK: - getSaplingAddress

    var getSaplingAddressAccountIndexThrowableError: Error?
    var getSaplingAddressAccountIndexCallsCount = 0
    var getSaplingAddressAccountIndexCalled: Bool {
        return getSaplingAddressAccountIndexCallsCount > 0
    }
    var getSaplingAddressAccountIndexReceivedAccountIndex: Int?
    var getSaplingAddressAccountIndexReturnValue: SaplingAddress!
    var getSaplingAddressAccountIndexClosure: ((Int) async throws -> SaplingAddress)?

    func getSaplingAddress(accountIndex: Int) async throws -> SaplingAddress {
        if let error = getSaplingAddressAccountIndexThrowableError {
            throw error
        }
        getSaplingAddressAccountIndexCallsCount += 1
        getSaplingAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getSaplingAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getSaplingAddressAccountIndexReturnValue
        }
    }

    // MARK: - getUnifiedAddress

    var getUnifiedAddressAccountIndexThrowableError: Error?
    var getUnifiedAddressAccountIndexCallsCount = 0
    var getUnifiedAddressAccountIndexCalled: Bool {
        return getUnifiedAddressAccountIndexCallsCount > 0
    }
    var getUnifiedAddressAccountIndexReceivedAccountIndex: Int?
    var getUnifiedAddressAccountIndexReturnValue: UnifiedAddress!
    var getUnifiedAddressAccountIndexClosure: ((Int) async throws -> UnifiedAddress)?

    func getUnifiedAddress(accountIndex: Int) async throws -> UnifiedAddress {
        if let error = getUnifiedAddressAccountIndexThrowableError {
            throw error
        }
        getUnifiedAddressAccountIndexCallsCount += 1
        getUnifiedAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getUnifiedAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getUnifiedAddressAccountIndexReturnValue
        }
    }

    // MARK: - getTransparentAddress

    var getTransparentAddressAccountIndexThrowableError: Error?
    var getTransparentAddressAccountIndexCallsCount = 0
    var getTransparentAddressAccountIndexCalled: Bool {
        return getTransparentAddressAccountIndexCallsCount > 0
    }
    var getTransparentAddressAccountIndexReceivedAccountIndex: Int?
    var getTransparentAddressAccountIndexReturnValue: TransparentAddress!
    var getTransparentAddressAccountIndexClosure: ((Int) async throws -> TransparentAddress)?

    func getTransparentAddress(accountIndex: Int) async throws -> TransparentAddress {
        if let error = getTransparentAddressAccountIndexThrowableError {
            throw error
        }
        getTransparentAddressAccountIndexCallsCount += 1
        getTransparentAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getTransparentAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getTransparentAddressAccountIndexReturnValue
        }
    }

    // MARK: - sendToAddress

    var sendToAddressSpendingKeyZatoshiToAddressMemoThrowableError: Error?
    var sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount = 0
    var sendToAddressSpendingKeyZatoshiToAddressMemoCalled: Bool {
        return sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount > 0
    }
    var sendToAddressSpendingKeyZatoshiToAddressMemoReceivedArguments: (spendingKey: UnifiedSpendingKey, zatoshi: Zatoshi, toAddress: Recipient, memo: Memo?)?
    var sendToAddressSpendingKeyZatoshiToAddressMemoReturnValue: PendingTransactionEntity!
    var sendToAddressSpendingKeyZatoshiToAddressMemoClosure: ((UnifiedSpendingKey, Zatoshi, Recipient, Memo?) async throws -> PendingTransactionEntity)?

    func sendToAddress(spendingKey: UnifiedSpendingKey, zatoshi: Zatoshi, toAddress: Recipient, memo: Memo?) async throws -> PendingTransactionEntity {
        if let error = sendToAddressSpendingKeyZatoshiToAddressMemoThrowableError {
            throw error
        }
        sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount += 1
        sendToAddressSpendingKeyZatoshiToAddressMemoReceivedArguments = (spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        if let closure = sendToAddressSpendingKeyZatoshiToAddressMemoClosure {
            return try await closure(spendingKey, zatoshi, toAddress, memo)
        } else {
            return sendToAddressSpendingKeyZatoshiToAddressMemoReturnValue
        }
    }

    // MARK: - shieldFunds

    var shieldFundsSpendingKeyMemoShieldingThresholdThrowableError: Error?
    var shieldFundsSpendingKeyMemoShieldingThresholdCallsCount = 0
    var shieldFundsSpendingKeyMemoShieldingThresholdCalled: Bool {
        return shieldFundsSpendingKeyMemoShieldingThresholdCallsCount > 0
    }
    var shieldFundsSpendingKeyMemoShieldingThresholdReceivedArguments: (spendingKey: UnifiedSpendingKey, memo: Memo, shieldingThreshold: Zatoshi)?
    var shieldFundsSpendingKeyMemoShieldingThresholdReturnValue: PendingTransactionEntity!
    var shieldFundsSpendingKeyMemoShieldingThresholdClosure: ((UnifiedSpendingKey, Memo, Zatoshi) async throws -> PendingTransactionEntity)?

    func shieldFunds(spendingKey: UnifiedSpendingKey, memo: Memo, shieldingThreshold: Zatoshi) async throws -> PendingTransactionEntity {
        if let error = shieldFundsSpendingKeyMemoShieldingThresholdThrowableError {
            throw error
        }
        shieldFundsSpendingKeyMemoShieldingThresholdCallsCount += 1
        shieldFundsSpendingKeyMemoShieldingThresholdReceivedArguments = (spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        if let closure = shieldFundsSpendingKeyMemoShieldingThresholdClosure {
            return try await closure(spendingKey, memo, shieldingThreshold)
        } else {
            return shieldFundsSpendingKeyMemoShieldingThresholdReturnValue
        }
    }

    // MARK: - cancelSpend

    var cancelSpendTransactionCallsCount = 0
    var cancelSpendTransactionCalled: Bool {
        return cancelSpendTransactionCallsCount > 0
    }
    var cancelSpendTransactionReceivedTransaction: PendingTransactionEntity?
    var cancelSpendTransactionReturnValue: Bool!
    var cancelSpendTransactionClosure: ((PendingTransactionEntity) async -> Bool)?

    func cancelSpend(transaction: PendingTransactionEntity) async -> Bool {
        cancelSpendTransactionCallsCount += 1
        cancelSpendTransactionReceivedTransaction = transaction
        if let closure = cancelSpendTransactionClosure {
            return await closure(transaction)
        } else {
            return cancelSpendTransactionReturnValue
        }
    }

    // MARK: - paginatedTransactions

    var paginatedTransactionsOfCallsCount = 0
    var paginatedTransactionsOfCalled: Bool {
        return paginatedTransactionsOfCallsCount > 0
    }
    var paginatedTransactionsOfReceivedKind: TransactionKind?
    var paginatedTransactionsOfReturnValue: PaginatedTransactionRepository!
    var paginatedTransactionsOfClosure: ((TransactionKind) -> PaginatedTransactionRepository)?

    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository {
        paginatedTransactionsOfCallsCount += 1
        paginatedTransactionsOfReceivedKind = kind
        if let closure = paginatedTransactionsOfClosure {
            return closure(kind)
        } else {
            return paginatedTransactionsOfReturnValue
        }
    }

    // MARK: - getMemos

    var getMemosForClearedTransactionThrowableError: Error?
    var getMemosForClearedTransactionCallsCount = 0
    var getMemosForClearedTransactionCalled: Bool {
        return getMemosForClearedTransactionCallsCount > 0
    }
    var getMemosForClearedTransactionReceivedTransaction: ZcashTransaction.Overview?
    var getMemosForClearedTransactionReturnValue: [Memo]!
    var getMemosForClearedTransactionClosure: ((ZcashTransaction.Overview) async throws -> [Memo])?

    func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        if let error = getMemosForClearedTransactionThrowableError {
            throw error
        }
        getMemosForClearedTransactionCallsCount += 1
        getMemosForClearedTransactionReceivedTransaction = transaction
        if let closure = getMemosForClearedTransactionClosure {
            return try await closure(transaction)
        } else {
            return getMemosForClearedTransactionReturnValue
        }
    }

    // MARK: - getMemos

    var getMemosForReceivedTransactionThrowableError: Error?
    var getMemosForReceivedTransactionCallsCount = 0
    var getMemosForReceivedTransactionCalled: Bool {
        return getMemosForReceivedTransactionCallsCount > 0
    }
    var getMemosForReceivedTransactionReceivedReceivedTransaction: ZcashTransaction.Received?
    var getMemosForReceivedTransactionReturnValue: [Memo]!
    var getMemosForReceivedTransactionClosure: ((ZcashTransaction.Received) async throws -> [Memo])?

    func getMemos(for receivedTransaction: ZcashTransaction.Received) async throws -> [Memo] {
        if let error = getMemosForReceivedTransactionThrowableError {
            throw error
        }
        getMemosForReceivedTransactionCallsCount += 1
        getMemosForReceivedTransactionReceivedReceivedTransaction = receivedTransaction
        if let closure = getMemosForReceivedTransactionClosure {
            return try await closure(receivedTransaction)
        } else {
            return getMemosForReceivedTransactionReturnValue
        }
    }

    // MARK: - getMemos

    var getMemosForSentTransactionThrowableError: Error?
    var getMemosForSentTransactionCallsCount = 0
    var getMemosForSentTransactionCalled: Bool {
        return getMemosForSentTransactionCallsCount > 0
    }
    var getMemosForSentTransactionReceivedSentTransaction: ZcashTransaction.Sent?
    var getMemosForSentTransactionReturnValue: [Memo]!
    var getMemosForSentTransactionClosure: ((ZcashTransaction.Sent) async throws -> [Memo])?

    func getMemos(for sentTransaction: ZcashTransaction.Sent) async throws -> [Memo] {
        if let error = getMemosForSentTransactionThrowableError {
            throw error
        }
        getMemosForSentTransactionCallsCount += 1
        getMemosForSentTransactionReceivedSentTransaction = sentTransaction
        if let closure = getMemosForSentTransactionClosure {
            return try await closure(sentTransaction)
        } else {
            return getMemosForSentTransactionReturnValue
        }
    }

    // MARK: - getRecipients

    var getRecipientsForClearedTransactionCallsCount = 0
    var getRecipientsForClearedTransactionCalled: Bool {
        return getRecipientsForClearedTransactionCallsCount > 0
    }
    var getRecipientsForClearedTransactionReceivedTransaction: ZcashTransaction.Overview?
    var getRecipientsForClearedTransactionReturnValue: [TransactionRecipient]!
    var getRecipientsForClearedTransactionClosure: ((ZcashTransaction.Overview) async -> [TransactionRecipient])?

    func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient] {
        getRecipientsForClearedTransactionCallsCount += 1
        getRecipientsForClearedTransactionReceivedTransaction = transaction
        if let closure = getRecipientsForClearedTransactionClosure {
            return await closure(transaction)
        } else {
            return getRecipientsForClearedTransactionReturnValue
        }
    }

    // MARK: - getRecipients

    var getRecipientsForSentTransactionCallsCount = 0
    var getRecipientsForSentTransactionCalled: Bool {
        return getRecipientsForSentTransactionCallsCount > 0
    }
    var getRecipientsForSentTransactionReceivedTransaction: ZcashTransaction.Sent?
    var getRecipientsForSentTransactionReturnValue: [TransactionRecipient]!
    var getRecipientsForSentTransactionClosure: ((ZcashTransaction.Sent) async -> [TransactionRecipient])?

    func getRecipients(for transaction: ZcashTransaction.Sent) async -> [TransactionRecipient] {
        getRecipientsForSentTransactionCallsCount += 1
        getRecipientsForSentTransactionReceivedTransaction = transaction
        if let closure = getRecipientsForSentTransactionClosure {
            return await closure(transaction)
        } else {
            return getRecipientsForSentTransactionReturnValue
        }
    }

    // MARK: - allConfirmedTransactions

    var allConfirmedTransactionsFromLimitThrowableError: Error?
    var allConfirmedTransactionsFromLimitCallsCount = 0
    var allConfirmedTransactionsFromLimitCalled: Bool {
        return allConfirmedTransactionsFromLimitCallsCount > 0
    }
    var allConfirmedTransactionsFromLimitReceivedArguments: (transaction: ZcashTransaction.Overview, limit: Int)?
    var allConfirmedTransactionsFromLimitReturnValue: [ZcashTransaction.Overview]!
    var allConfirmedTransactionsFromLimitClosure: ((ZcashTransaction.Overview, Int) async throws -> [ZcashTransaction.Overview])?

    func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview] {
        if let error = allConfirmedTransactionsFromLimitThrowableError {
            throw error
        }
        allConfirmedTransactionsFromLimitCallsCount += 1
        allConfirmedTransactionsFromLimitReceivedArguments = (transaction: transaction, limit: limit)
        if let closure = allConfirmedTransactionsFromLimitClosure {
            return try await closure(transaction, limit)
        } else {
            return allConfirmedTransactionsFromLimitReturnValue
        }
    }

    // MARK: - latestHeight

    var latestHeightThrowableError: Error?
    var latestHeightCallsCount = 0
    var latestHeightCalled: Bool {
        return latestHeightCallsCount > 0
    }
    var latestHeightReturnValue: BlockHeight!
    var latestHeightClosure: (() async throws -> BlockHeight)?

    func latestHeight() async throws -> BlockHeight {
        if let error = latestHeightThrowableError {
            throw error
        }
        latestHeightCallsCount += 1
        if let closure = latestHeightClosure {
            return try await closure()
        } else {
            return latestHeightReturnValue
        }
    }

    // MARK: - refreshUTXOs

    var refreshUTXOsAddressFromThrowableError: Error?
    var refreshUTXOsAddressFromCallsCount = 0
    var refreshUTXOsAddressFromCalled: Bool {
        return refreshUTXOsAddressFromCallsCount > 0
    }
    var refreshUTXOsAddressFromReceivedArguments: (address: TransparentAddress, height: BlockHeight)?
    var refreshUTXOsAddressFromReturnValue: RefreshedUTXOs!
    var refreshUTXOsAddressFromClosure: ((TransparentAddress, BlockHeight) async throws -> RefreshedUTXOs)?

    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        if let error = refreshUTXOsAddressFromThrowableError {
            throw error
        }
        refreshUTXOsAddressFromCallsCount += 1
        refreshUTXOsAddressFromReceivedArguments = (address: address, height: height)
        if let closure = refreshUTXOsAddressFromClosure {
            return try await closure(address, height)
        } else {
            return refreshUTXOsAddressFromReturnValue
        }
    }

    // MARK: - getTransparentBalance

    var getTransparentBalanceAccountIndexThrowableError: Error?
    var getTransparentBalanceAccountIndexCallsCount = 0
    var getTransparentBalanceAccountIndexCalled: Bool {
        return getTransparentBalanceAccountIndexCallsCount > 0
    }
    var getTransparentBalanceAccountIndexReceivedAccountIndex: Int?
    var getTransparentBalanceAccountIndexReturnValue: WalletBalance!
    var getTransparentBalanceAccountIndexClosure: ((Int) async throws -> WalletBalance)?

    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance {
        if let error = getTransparentBalanceAccountIndexThrowableError {
            throw error
        }
        getTransparentBalanceAccountIndexCallsCount += 1
        getTransparentBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getTransparentBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getTransparentBalanceAccountIndexReturnValue
        }
    }

    // MARK: - getShieldedBalance

    var getShieldedBalanceAccountIndexThrowableError: Error?
    var getShieldedBalanceAccountIndexCallsCount = 0
    var getShieldedBalanceAccountIndexCalled: Bool {
        return getShieldedBalanceAccountIndexCallsCount > 0
    }
    var getShieldedBalanceAccountIndexReceivedAccountIndex: Int?
    var getShieldedBalanceAccountIndexReturnValue: Zatoshi!
    var getShieldedBalanceAccountIndexClosure: ((Int) async throws -> Zatoshi)?

    func getShieldedBalance(accountIndex: Int) async throws -> Zatoshi {
        if let error = getShieldedBalanceAccountIndexThrowableError {
            throw error
        }
        getShieldedBalanceAccountIndexCallsCount += 1
        getShieldedBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getShieldedBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getShieldedBalanceAccountIndexReturnValue
        }
    }

    // MARK: - getShieldedVerifiedBalance

    var getShieldedVerifiedBalanceAccountIndexThrowableError: Error?
    var getShieldedVerifiedBalanceAccountIndexCallsCount = 0
    var getShieldedVerifiedBalanceAccountIndexCalled: Bool {
        return getShieldedVerifiedBalanceAccountIndexCallsCount > 0
    }
    var getShieldedVerifiedBalanceAccountIndexReceivedAccountIndex: Int?
    var getShieldedVerifiedBalanceAccountIndexReturnValue: Zatoshi!
    var getShieldedVerifiedBalanceAccountIndexClosure: ((Int) async throws -> Zatoshi)?

    func getShieldedVerifiedBalance(accountIndex: Int) async throws -> Zatoshi {
        if let error = getShieldedVerifiedBalanceAccountIndexThrowableError {
            throw error
        }
        getShieldedVerifiedBalanceAccountIndexCallsCount += 1
        getShieldedVerifiedBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getShieldedVerifiedBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getShieldedVerifiedBalanceAccountIndexReturnValue
        }
    }

    // MARK: - rewind

    var rewindCallsCount = 0
    var rewindCalled: Bool {
        return rewindCallsCount > 0
    }
    var rewindReceivedPolicy: RewindPolicy?
    var rewindReturnValue: AnyPublisher<Void, Error>!
    var rewindClosure: ((RewindPolicy) -> AnyPublisher<Void, Error>)?

    func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error> {
        rewindCallsCount += 1
        rewindReceivedPolicy = policy
        if let closure = rewindClosure {
            return closure(policy)
        } else {
            return rewindReturnValue
        }
    }

    // MARK: - wipe

    var wipeCallsCount = 0
    var wipeCalled: Bool {
        return wipeCallsCount > 0
    }
    var wipeReturnValue: AnyPublisher<Void, Error>!
    var wipeClosure: (() -> AnyPublisher<Void, Error>)?

    func wipe() -> AnyPublisher<Void, Error> {
        wipeCallsCount += 1
        if let closure = wipeClosure {
            return closure()
        } else {
            return wipeReturnValue
        }
    }

}
actor ZcashRustBackendWeldingMock: ZcashRustBackendWelding {

    nonisolated let consensusBranchIdForHeightClosure: ((Int32) throws -> Int32)?

    init(
        consensusBranchIdForHeightClosure: ((Int32) throws -> Int32)? = nil
    ) {
        self.consensusBranchIdForHeightClosure = consensusBranchIdForHeightClosure
    }

    // MARK: - createAccount

    var createAccountSeedThrowableError: Error?
    func setCreateAccountSeedThrowableError(_ param: Error?) async {
        createAccountSeedThrowableError = param
    }
    var createAccountSeedCallsCount = 0
    var createAccountSeedCalled: Bool {
        return createAccountSeedCallsCount > 0
    }
    var createAccountSeedReceivedSeed: [UInt8]?
    var createAccountSeedReturnValue: UnifiedSpendingKey!
    func setCreateAccountSeedReturnValue(_ param: UnifiedSpendingKey) async {
        createAccountSeedReturnValue = param
    }
    var createAccountSeedClosure: (([UInt8]) async throws -> UnifiedSpendingKey)?
    func setCreateAccountSeedClosure(_ param: (([UInt8]) async throws -> UnifiedSpendingKey)?) async {
        createAccountSeedClosure = param
    }

    func createAccount(seed: [UInt8]) async throws -> UnifiedSpendingKey {
        if let error = createAccountSeedThrowableError {
            throw error
        }
        createAccountSeedCallsCount += 1
        createAccountSeedReceivedSeed = seed
        if let closure = createAccountSeedClosure {
            return try await closure(seed)
        } else {
            return createAccountSeedReturnValue
        }
    }

    // MARK: - createToAddress

    var createToAddressUskToValueMemoThrowableError: Error?
    func setCreateToAddressUskToValueMemoThrowableError(_ param: Error?) async {
        createToAddressUskToValueMemoThrowableError = param
    }
    var createToAddressUskToValueMemoCallsCount = 0
    var createToAddressUskToValueMemoCalled: Bool {
        return createToAddressUskToValueMemoCallsCount > 0
    }
    var createToAddressUskToValueMemoReceivedArguments: (usk: UnifiedSpendingKey, address: String, value: Int64, memo: MemoBytes?)?
    var createToAddressUskToValueMemoReturnValue: Int64!
    func setCreateToAddressUskToValueMemoReturnValue(_ param: Int64) async {
        createToAddressUskToValueMemoReturnValue = param
    }
    var createToAddressUskToValueMemoClosure: ((UnifiedSpendingKey, String, Int64, MemoBytes?) async throws -> Int64)?
    func setCreateToAddressUskToValueMemoClosure(_ param: ((UnifiedSpendingKey, String, Int64, MemoBytes?) async throws -> Int64)?) async {
        createToAddressUskToValueMemoClosure = param
    }

    func createToAddress(usk: UnifiedSpendingKey, to address: String, value: Int64, memo: MemoBytes?) async throws -> Int64 {
        if let error = createToAddressUskToValueMemoThrowableError {
            throw error
        }
        createToAddressUskToValueMemoCallsCount += 1
        createToAddressUskToValueMemoReceivedArguments = (usk: usk, address: address, value: value, memo: memo)
        if let closure = createToAddressUskToValueMemoClosure {
            return try await closure(usk, address, value, memo)
        } else {
            return createToAddressUskToValueMemoReturnValue
        }
    }

    // MARK: - decryptAndStoreTransaction

    var decryptAndStoreTransactionTxBytesMinedHeightThrowableError: Error?
    func setDecryptAndStoreTransactionTxBytesMinedHeightThrowableError(_ param: Error?) async {
        decryptAndStoreTransactionTxBytesMinedHeightThrowableError = param
    }
    var decryptAndStoreTransactionTxBytesMinedHeightCallsCount = 0
    var decryptAndStoreTransactionTxBytesMinedHeightCalled: Bool {
        return decryptAndStoreTransactionTxBytesMinedHeightCallsCount > 0
    }
    var decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments: (txBytes: [UInt8], minedHeight: Int32)?
    var decryptAndStoreTransactionTxBytesMinedHeightClosure: (([UInt8], Int32) async throws -> Void)?
    func setDecryptAndStoreTransactionTxBytesMinedHeightClosure(_ param: (([UInt8], Int32) async throws -> Void)?) async {
        decryptAndStoreTransactionTxBytesMinedHeightClosure = param
    }

    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws {
        if let error = decryptAndStoreTransactionTxBytesMinedHeightThrowableError {
            throw error
        }
        decryptAndStoreTransactionTxBytesMinedHeightCallsCount += 1
        decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments = (txBytes: txBytes, minedHeight: minedHeight)
        try await decryptAndStoreTransactionTxBytesMinedHeightClosure?(txBytes, minedHeight)
    }

    // MARK: - getBalance

    var getBalanceAccountThrowableError: Error?
    func setGetBalanceAccountThrowableError(_ param: Error?) async {
        getBalanceAccountThrowableError = param
    }
    var getBalanceAccountCallsCount = 0
    var getBalanceAccountCalled: Bool {
        return getBalanceAccountCallsCount > 0
    }
    var getBalanceAccountReceivedAccount: Int32?
    var getBalanceAccountReturnValue: Int64!
    func setGetBalanceAccountReturnValue(_ param: Int64) async {
        getBalanceAccountReturnValue = param
    }
    var getBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getBalanceAccountClosure = param
    }

    func getBalance(account: Int32) async throws -> Int64 {
        if let error = getBalanceAccountThrowableError {
            throw error
        }
        getBalanceAccountCallsCount += 1
        getBalanceAccountReceivedAccount = account
        if let closure = getBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getBalanceAccountReturnValue
        }
    }

    // MARK: - getCurrentAddress

    var getCurrentAddressAccountThrowableError: Error?
    func setGetCurrentAddressAccountThrowableError(_ param: Error?) async {
        getCurrentAddressAccountThrowableError = param
    }
    var getCurrentAddressAccountCallsCount = 0
    var getCurrentAddressAccountCalled: Bool {
        return getCurrentAddressAccountCallsCount > 0
    }
    var getCurrentAddressAccountReceivedAccount: Int32?
    var getCurrentAddressAccountReturnValue: UnifiedAddress!
    func setGetCurrentAddressAccountReturnValue(_ param: UnifiedAddress) async {
        getCurrentAddressAccountReturnValue = param
    }
    var getCurrentAddressAccountClosure: ((Int32) async throws -> UnifiedAddress)?
    func setGetCurrentAddressAccountClosure(_ param: ((Int32) async throws -> UnifiedAddress)?) async {
        getCurrentAddressAccountClosure = param
    }

    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress {
        if let error = getCurrentAddressAccountThrowableError {
            throw error
        }
        getCurrentAddressAccountCallsCount += 1
        getCurrentAddressAccountReceivedAccount = account
        if let closure = getCurrentAddressAccountClosure {
            return try await closure(account)
        } else {
            return getCurrentAddressAccountReturnValue
        }
    }

    // MARK: - getNearestRewindHeight

    var getNearestRewindHeightHeightThrowableError: Error?
    func setGetNearestRewindHeightHeightThrowableError(_ param: Error?) async {
        getNearestRewindHeightHeightThrowableError = param
    }
    var getNearestRewindHeightHeightCallsCount = 0
    var getNearestRewindHeightHeightCalled: Bool {
        return getNearestRewindHeightHeightCallsCount > 0
    }
    var getNearestRewindHeightHeightReceivedHeight: Int32?
    var getNearestRewindHeightHeightReturnValue: Int32!
    func setGetNearestRewindHeightHeightReturnValue(_ param: Int32) async {
        getNearestRewindHeightHeightReturnValue = param
    }
    var getNearestRewindHeightHeightClosure: ((Int32) async throws -> Int32)?
    func setGetNearestRewindHeightHeightClosure(_ param: ((Int32) async throws -> Int32)?) async {
        getNearestRewindHeightHeightClosure = param
    }

    func getNearestRewindHeight(height: Int32) async throws -> Int32 {
        if let error = getNearestRewindHeightHeightThrowableError {
            throw error
        }
        getNearestRewindHeightHeightCallsCount += 1
        getNearestRewindHeightHeightReceivedHeight = height
        if let closure = getNearestRewindHeightHeightClosure {
            return try await closure(height)
        } else {
            return getNearestRewindHeightHeightReturnValue
        }
    }

    // MARK: - getNextAvailableAddress

    var getNextAvailableAddressAccountThrowableError: Error?
    func setGetNextAvailableAddressAccountThrowableError(_ param: Error?) async {
        getNextAvailableAddressAccountThrowableError = param
    }
    var getNextAvailableAddressAccountCallsCount = 0
    var getNextAvailableAddressAccountCalled: Bool {
        return getNextAvailableAddressAccountCallsCount > 0
    }
    var getNextAvailableAddressAccountReceivedAccount: Int32?
    var getNextAvailableAddressAccountReturnValue: UnifiedAddress!
    func setGetNextAvailableAddressAccountReturnValue(_ param: UnifiedAddress) async {
        getNextAvailableAddressAccountReturnValue = param
    }
    var getNextAvailableAddressAccountClosure: ((Int32) async throws -> UnifiedAddress)?
    func setGetNextAvailableAddressAccountClosure(_ param: ((Int32) async throws -> UnifiedAddress)?) async {
        getNextAvailableAddressAccountClosure = param
    }

    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress {
        if let error = getNextAvailableAddressAccountThrowableError {
            throw error
        }
        getNextAvailableAddressAccountCallsCount += 1
        getNextAvailableAddressAccountReceivedAccount = account
        if let closure = getNextAvailableAddressAccountClosure {
            return try await closure(account)
        } else {
            return getNextAvailableAddressAccountReturnValue
        }
    }

    // MARK: - getReceivedMemo

    var getReceivedMemoIdNoteCallsCount = 0
    var getReceivedMemoIdNoteCalled: Bool {
        return getReceivedMemoIdNoteCallsCount > 0
    }
    var getReceivedMemoIdNoteReceivedIdNote: Int64?
    var getReceivedMemoIdNoteReturnValue: Memo?
    func setGetReceivedMemoIdNoteReturnValue(_ param: Memo?) async {
        getReceivedMemoIdNoteReturnValue = param
    }
    var getReceivedMemoIdNoteClosure: ((Int64) async -> Memo?)?
    func setGetReceivedMemoIdNoteClosure(_ param: ((Int64) async -> Memo?)?) async {
        getReceivedMemoIdNoteClosure = param
    }

    func getReceivedMemo(idNote: Int64) async -> Memo? {
        getReceivedMemoIdNoteCallsCount += 1
        getReceivedMemoIdNoteReceivedIdNote = idNote
        if let closure = getReceivedMemoIdNoteClosure {
            return await closure(idNote)
        } else {
            return getReceivedMemoIdNoteReturnValue
        }
    }

    // MARK: - getSentMemo

    var getSentMemoIdNoteCallsCount = 0
    var getSentMemoIdNoteCalled: Bool {
        return getSentMemoIdNoteCallsCount > 0
    }
    var getSentMemoIdNoteReceivedIdNote: Int64?
    var getSentMemoIdNoteReturnValue: Memo?
    func setGetSentMemoIdNoteReturnValue(_ param: Memo?) async {
        getSentMemoIdNoteReturnValue = param
    }
    var getSentMemoIdNoteClosure: ((Int64) async -> Memo?)?
    func setGetSentMemoIdNoteClosure(_ param: ((Int64) async -> Memo?)?) async {
        getSentMemoIdNoteClosure = param
    }

    func getSentMemo(idNote: Int64) async -> Memo? {
        getSentMemoIdNoteCallsCount += 1
        getSentMemoIdNoteReceivedIdNote = idNote
        if let closure = getSentMemoIdNoteClosure {
            return await closure(idNote)
        } else {
            return getSentMemoIdNoteReturnValue
        }
    }

    // MARK: - getTransparentBalance

    var getTransparentBalanceAccountThrowableError: Error?
    func setGetTransparentBalanceAccountThrowableError(_ param: Error?) async {
        getTransparentBalanceAccountThrowableError = param
    }
    var getTransparentBalanceAccountCallsCount = 0
    var getTransparentBalanceAccountCalled: Bool {
        return getTransparentBalanceAccountCallsCount > 0
    }
    var getTransparentBalanceAccountReceivedAccount: Int32?
    var getTransparentBalanceAccountReturnValue: Int64!
    func setGetTransparentBalanceAccountReturnValue(_ param: Int64) async {
        getTransparentBalanceAccountReturnValue = param
    }
    var getTransparentBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetTransparentBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getTransparentBalanceAccountClosure = param
    }

    func getTransparentBalance(account: Int32) async throws -> Int64 {
        if let error = getTransparentBalanceAccountThrowableError {
            throw error
        }
        getTransparentBalanceAccountCallsCount += 1
        getTransparentBalanceAccountReceivedAccount = account
        if let closure = getTransparentBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getTransparentBalanceAccountReturnValue
        }
    }

    // MARK: - initAccountsTable

    var initAccountsTableUfvksThrowableError: Error?
    func setInitAccountsTableUfvksThrowableError(_ param: Error?) async {
        initAccountsTableUfvksThrowableError = param
    }
    var initAccountsTableUfvksCallsCount = 0
    var initAccountsTableUfvksCalled: Bool {
        return initAccountsTableUfvksCallsCount > 0
    }
    var initAccountsTableUfvksReceivedUfvks: [UnifiedFullViewingKey]?
    var initAccountsTableUfvksClosure: (([UnifiedFullViewingKey]) async throws -> Void)?
    func setInitAccountsTableUfvksClosure(_ param: (([UnifiedFullViewingKey]) async throws -> Void)?) async {
        initAccountsTableUfvksClosure = param
    }

    func initAccountsTable(ufvks: [UnifiedFullViewingKey]) async throws {
        if let error = initAccountsTableUfvksThrowableError {
            throw error
        }
        initAccountsTableUfvksCallsCount += 1
        initAccountsTableUfvksReceivedUfvks = ufvks
        try await initAccountsTableUfvksClosure?(ufvks)
    }

    // MARK: - initDataDb

    var initDataDbSeedThrowableError: Error?
    func setInitDataDbSeedThrowableError(_ param: Error?) async {
        initDataDbSeedThrowableError = param
    }
    var initDataDbSeedCallsCount = 0
    var initDataDbSeedCalled: Bool {
        return initDataDbSeedCallsCount > 0
    }
    var initDataDbSeedReceivedSeed: [UInt8]?
    var initDataDbSeedReturnValue: DbInitResult!
    func setInitDataDbSeedReturnValue(_ param: DbInitResult) async {
        initDataDbSeedReturnValue = param
    }
    var initDataDbSeedClosure: (([UInt8]?) async throws -> DbInitResult)?
    func setInitDataDbSeedClosure(_ param: (([UInt8]?) async throws -> DbInitResult)?) async {
        initDataDbSeedClosure = param
    }

    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult {
        if let error = initDataDbSeedThrowableError {
            throw error
        }
        initDataDbSeedCallsCount += 1
        initDataDbSeedReceivedSeed = seed
        if let closure = initDataDbSeedClosure {
            return try await closure(seed)
        } else {
            return initDataDbSeedReturnValue
        }
    }

    // MARK: - initBlocksTable

    var initBlocksTableHeightHashTimeSaplingTreeThrowableError: Error?
    func setInitBlocksTableHeightHashTimeSaplingTreeThrowableError(_ param: Error?) async {
        initBlocksTableHeightHashTimeSaplingTreeThrowableError = param
    }
    var initBlocksTableHeightHashTimeSaplingTreeCallsCount = 0
    var initBlocksTableHeightHashTimeSaplingTreeCalled: Bool {
        return initBlocksTableHeightHashTimeSaplingTreeCallsCount > 0
    }
    var initBlocksTableHeightHashTimeSaplingTreeReceivedArguments: (height: Int32, hash: String, time: UInt32, saplingTree: String)?
    var initBlocksTableHeightHashTimeSaplingTreeClosure: ((Int32, String, UInt32, String) async throws -> Void)?
    func setInitBlocksTableHeightHashTimeSaplingTreeClosure(_ param: ((Int32, String, UInt32, String) async throws -> Void)?) async {
        initBlocksTableHeightHashTimeSaplingTreeClosure = param
    }

    func initBlocksTable(height: Int32, hash: String, time: UInt32, saplingTree: String) async throws {
        if let error = initBlocksTableHeightHashTimeSaplingTreeThrowableError {
            throw error
        }
        initBlocksTableHeightHashTimeSaplingTreeCallsCount += 1
        initBlocksTableHeightHashTimeSaplingTreeReceivedArguments = (height: height, hash: hash, time: time, saplingTree: saplingTree)
        try await initBlocksTableHeightHashTimeSaplingTreeClosure?(height, hash, time, saplingTree)
    }

    // MARK: - listTransparentReceivers

    var listTransparentReceiversAccountThrowableError: Error?
    func setListTransparentReceiversAccountThrowableError(_ param: Error?) async {
        listTransparentReceiversAccountThrowableError = param
    }
    var listTransparentReceiversAccountCallsCount = 0
    var listTransparentReceiversAccountCalled: Bool {
        return listTransparentReceiversAccountCallsCount > 0
    }
    var listTransparentReceiversAccountReceivedAccount: Int32?
    var listTransparentReceiversAccountReturnValue: [TransparentAddress]!
    func setListTransparentReceiversAccountReturnValue(_ param: [TransparentAddress]) async {
        listTransparentReceiversAccountReturnValue = param
    }
    var listTransparentReceiversAccountClosure: ((Int32) async throws -> [TransparentAddress])?
    func setListTransparentReceiversAccountClosure(_ param: ((Int32) async throws -> [TransparentAddress])?) async {
        listTransparentReceiversAccountClosure = param
    }

    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress] {
        if let error = listTransparentReceiversAccountThrowableError {
            throw error
        }
        listTransparentReceiversAccountCallsCount += 1
        listTransparentReceiversAccountReceivedAccount = account
        if let closure = listTransparentReceiversAccountClosure {
            return try await closure(account)
        } else {
            return listTransparentReceiversAccountReturnValue
        }
    }

    // MARK: - getVerifiedBalance

    var getVerifiedBalanceAccountThrowableError: Error?
    func setGetVerifiedBalanceAccountThrowableError(_ param: Error?) async {
        getVerifiedBalanceAccountThrowableError = param
    }
    var getVerifiedBalanceAccountCallsCount = 0
    var getVerifiedBalanceAccountCalled: Bool {
        return getVerifiedBalanceAccountCallsCount > 0
    }
    var getVerifiedBalanceAccountReceivedAccount: Int32?
    var getVerifiedBalanceAccountReturnValue: Int64!
    func setGetVerifiedBalanceAccountReturnValue(_ param: Int64) async {
        getVerifiedBalanceAccountReturnValue = param
    }
    var getVerifiedBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetVerifiedBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getVerifiedBalanceAccountClosure = param
    }

    func getVerifiedBalance(account: Int32) async throws -> Int64 {
        if let error = getVerifiedBalanceAccountThrowableError {
            throw error
        }
        getVerifiedBalanceAccountCallsCount += 1
        getVerifiedBalanceAccountReceivedAccount = account
        if let closure = getVerifiedBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getVerifiedBalanceAccountReturnValue
        }
    }

    // MARK: - getVerifiedTransparentBalance

    var getVerifiedTransparentBalanceAccountThrowableError: Error?
    func setGetVerifiedTransparentBalanceAccountThrowableError(_ param: Error?) async {
        getVerifiedTransparentBalanceAccountThrowableError = param
    }
    var getVerifiedTransparentBalanceAccountCallsCount = 0
    var getVerifiedTransparentBalanceAccountCalled: Bool {
        return getVerifiedTransparentBalanceAccountCallsCount > 0
    }
    var getVerifiedTransparentBalanceAccountReceivedAccount: Int32?
    var getVerifiedTransparentBalanceAccountReturnValue: Int64!
    func setGetVerifiedTransparentBalanceAccountReturnValue(_ param: Int64) async {
        getVerifiedTransparentBalanceAccountReturnValue = param
    }
    var getVerifiedTransparentBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetVerifiedTransparentBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getVerifiedTransparentBalanceAccountClosure = param
    }

    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64 {
        if let error = getVerifiedTransparentBalanceAccountThrowableError {
            throw error
        }
        getVerifiedTransparentBalanceAccountCallsCount += 1
        getVerifiedTransparentBalanceAccountReceivedAccount = account
        if let closure = getVerifiedTransparentBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getVerifiedTransparentBalanceAccountReturnValue
        }
    }

    // MARK: - validateCombinedChain

    var validateCombinedChainLimitThrowableError: Error?
    func setValidateCombinedChainLimitThrowableError(_ param: Error?) async {
        validateCombinedChainLimitThrowableError = param
    }
    var validateCombinedChainLimitCallsCount = 0
    var validateCombinedChainLimitCalled: Bool {
        return validateCombinedChainLimitCallsCount > 0
    }
    var validateCombinedChainLimitReceivedLimit: UInt32?
    var validateCombinedChainLimitClosure: ((UInt32) async throws -> Void)?
    func setValidateCombinedChainLimitClosure(_ param: ((UInt32) async throws -> Void)?) async {
        validateCombinedChainLimitClosure = param
    }

    func validateCombinedChain(limit: UInt32) async throws {
        if let error = validateCombinedChainLimitThrowableError {
            throw error
        }
        validateCombinedChainLimitCallsCount += 1
        validateCombinedChainLimitReceivedLimit = limit
        try await validateCombinedChainLimitClosure?(limit)
    }

    // MARK: - rewindToHeight

    var rewindToHeightHeightThrowableError: Error?
    func setRewindToHeightHeightThrowableError(_ param: Error?) async {
        rewindToHeightHeightThrowableError = param
    }
    var rewindToHeightHeightCallsCount = 0
    var rewindToHeightHeightCalled: Bool {
        return rewindToHeightHeightCallsCount > 0
    }
    var rewindToHeightHeightReceivedHeight: Int32?
    var rewindToHeightHeightClosure: ((Int32) async throws -> Void)?
    func setRewindToHeightHeightClosure(_ param: ((Int32) async throws -> Void)?) async {
        rewindToHeightHeightClosure = param
    }

    func rewindToHeight(height: Int32) async throws {
        if let error = rewindToHeightHeightThrowableError {
            throw error
        }
        rewindToHeightHeightCallsCount += 1
        rewindToHeightHeightReceivedHeight = height
        try await rewindToHeightHeightClosure?(height)
    }

    // MARK: - rewindCacheToHeight

    var rewindCacheToHeightHeightThrowableError: Error?
    func setRewindCacheToHeightHeightThrowableError(_ param: Error?) async {
        rewindCacheToHeightHeightThrowableError = param
    }
    var rewindCacheToHeightHeightCallsCount = 0
    var rewindCacheToHeightHeightCalled: Bool {
        return rewindCacheToHeightHeightCallsCount > 0
    }
    var rewindCacheToHeightHeightReceivedHeight: Int32?
    var rewindCacheToHeightHeightClosure: ((Int32) async throws -> Void)?
    func setRewindCacheToHeightHeightClosure(_ param: ((Int32) async throws -> Void)?) async {
        rewindCacheToHeightHeightClosure = param
    }

    func rewindCacheToHeight(height: Int32) async throws {
        if let error = rewindCacheToHeightHeightThrowableError {
            throw error
        }
        rewindCacheToHeightHeightCallsCount += 1
        rewindCacheToHeightHeightReceivedHeight = height
        try await rewindCacheToHeightHeightClosure?(height)
    }

    // MARK: - scanBlocks

    var scanBlocksLimitThrowableError: Error?
    func setScanBlocksLimitThrowableError(_ param: Error?) async {
        scanBlocksLimitThrowableError = param
    }
    var scanBlocksLimitCallsCount = 0
    var scanBlocksLimitCalled: Bool {
        return scanBlocksLimitCallsCount > 0
    }
    var scanBlocksLimitReceivedLimit: UInt32?
    var scanBlocksLimitClosure: ((UInt32) async throws -> Void)?
    func setScanBlocksLimitClosure(_ param: ((UInt32) async throws -> Void)?) async {
        scanBlocksLimitClosure = param
    }

    func scanBlocks(limit: UInt32) async throws {
        if let error = scanBlocksLimitThrowableError {
            throw error
        }
        scanBlocksLimitCallsCount += 1
        scanBlocksLimitReceivedLimit = limit
        try await scanBlocksLimitClosure?(limit)
    }

    // MARK: - putUnspentTransparentOutput

    var putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError: Error?
    func setPutUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError(_ param: Error?) async {
        putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError = param
    }
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount = 0
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCalled: Bool {
        return putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount > 0
    }
    var putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments: (txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight)?
    var putUnspentTransparentOutputTxidIndexScriptValueHeightClosure: (([UInt8], Int, [UInt8], Int64, BlockHeight) async throws -> Void)?
    func setPutUnspentTransparentOutputTxidIndexScriptValueHeightClosure(_ param: (([UInt8], Int, [UInt8], Int64, BlockHeight) async throws -> Void)?) async {
        putUnspentTransparentOutputTxidIndexScriptValueHeightClosure = param
    }

    func putUnspentTransparentOutput(txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight) async throws {
        if let error = putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError {
            throw error
        }
        putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount += 1
        putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments = (txid: txid, index: index, script: script, value: value, height: height)
        try await putUnspentTransparentOutputTxidIndexScriptValueHeightClosure?(txid, index, script, value, height)
    }

    // MARK: - shieldFunds

    var shieldFundsUskMemoShieldingThresholdThrowableError: Error?
    func setShieldFundsUskMemoShieldingThresholdThrowableError(_ param: Error?) async {
        shieldFundsUskMemoShieldingThresholdThrowableError = param
    }
    var shieldFundsUskMemoShieldingThresholdCallsCount = 0
    var shieldFundsUskMemoShieldingThresholdCalled: Bool {
        return shieldFundsUskMemoShieldingThresholdCallsCount > 0
    }
    var shieldFundsUskMemoShieldingThresholdReceivedArguments: (usk: UnifiedSpendingKey, memo: MemoBytes?, shieldingThreshold: Zatoshi)?
    var shieldFundsUskMemoShieldingThresholdReturnValue: Int64!
    func setShieldFundsUskMemoShieldingThresholdReturnValue(_ param: Int64) async {
        shieldFundsUskMemoShieldingThresholdReturnValue = param
    }
    var shieldFundsUskMemoShieldingThresholdClosure: ((UnifiedSpendingKey, MemoBytes?, Zatoshi) async throws -> Int64)?
    func setShieldFundsUskMemoShieldingThresholdClosure(_ param: ((UnifiedSpendingKey, MemoBytes?, Zatoshi) async throws -> Int64)?) async {
        shieldFundsUskMemoShieldingThresholdClosure = param
    }

    func shieldFunds(usk: UnifiedSpendingKey, memo: MemoBytes?, shieldingThreshold: Zatoshi) async throws -> Int64 {
        if let error = shieldFundsUskMemoShieldingThresholdThrowableError {
            throw error
        }
        shieldFundsUskMemoShieldingThresholdCallsCount += 1
        shieldFundsUskMemoShieldingThresholdReceivedArguments = (usk: usk, memo: memo, shieldingThreshold: shieldingThreshold)
        if let closure = shieldFundsUskMemoShieldingThresholdClosure {
            return try await closure(usk, memo, shieldingThreshold)
        } else {
            return shieldFundsUskMemoShieldingThresholdReturnValue
        }
    }

    // MARK: - consensusBranchIdFor


    nonisolated func consensusBranchIdFor(height: Int32) throws -> Int32 {
        try consensusBranchIdForHeightClosure!(height)
    }

    // MARK: - initBlockMetadataDb

    var initBlockMetadataDbThrowableError: Error?
    func setInitBlockMetadataDbThrowableError(_ param: Error?) async {
        initBlockMetadataDbThrowableError = param
    }
    var initBlockMetadataDbCallsCount = 0
    var initBlockMetadataDbCalled: Bool {
        return initBlockMetadataDbCallsCount > 0
    }
    var initBlockMetadataDbClosure: (() async throws -> Void)?
    func setInitBlockMetadataDbClosure(_ param: (() async throws -> Void)?) async {
        initBlockMetadataDbClosure = param
    }

    func initBlockMetadataDb() async throws {
        if let error = initBlockMetadataDbThrowableError {
            throw error
        }
        initBlockMetadataDbCallsCount += 1
        try await initBlockMetadataDbClosure?()
    }

    // MARK: - writeBlocksMetadata

    var writeBlocksMetadataBlocksThrowableError: Error?
    func setWriteBlocksMetadataBlocksThrowableError(_ param: Error?) async {
        writeBlocksMetadataBlocksThrowableError = param
    }
    var writeBlocksMetadataBlocksCallsCount = 0
    var writeBlocksMetadataBlocksCalled: Bool {
        return writeBlocksMetadataBlocksCallsCount > 0
    }
    var writeBlocksMetadataBlocksReceivedBlocks: [ZcashCompactBlock]?
    var writeBlocksMetadataBlocksClosure: (([ZcashCompactBlock]) async throws -> Void)?
    func setWriteBlocksMetadataBlocksClosure(_ param: (([ZcashCompactBlock]) async throws -> Void)?) async {
        writeBlocksMetadataBlocksClosure = param
    }

    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws {
        if let error = writeBlocksMetadataBlocksThrowableError {
            throw error
        }
        writeBlocksMetadataBlocksCallsCount += 1
        writeBlocksMetadataBlocksReceivedBlocks = blocks
        try await writeBlocksMetadataBlocksClosure?(blocks)
    }

    // MARK: - latestCachedBlockHeight

    var latestCachedBlockHeightCallsCount = 0
    var latestCachedBlockHeightCalled: Bool {
        return latestCachedBlockHeightCallsCount > 0
    }
    var latestCachedBlockHeightReturnValue: BlockHeight!
    func setLatestCachedBlockHeightReturnValue(_ param: BlockHeight) async {
        latestCachedBlockHeightReturnValue = param
    }
    var latestCachedBlockHeightClosure: (() async -> BlockHeight)?
    func setLatestCachedBlockHeightClosure(_ param: (() async -> BlockHeight)?) async {
        latestCachedBlockHeightClosure = param
    }

    func latestCachedBlockHeight() async -> BlockHeight {
        latestCachedBlockHeightCallsCount += 1
        if let closure = latestCachedBlockHeightClosure {
            return await closure()
        } else {
            return latestCachedBlockHeightReturnValue
        }
    }

}
