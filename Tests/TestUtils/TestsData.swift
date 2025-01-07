//
//  TestsData.swift
//
//
//  Created by Michal Fousek on 20.03.2023.
//

import Foundation
@testable import ZcashLightClientKit

class TestsData {
    let networkType: NetworkType

    lazy var initialier = {
        Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: URL(fileURLWithPath: "/"),
            generalStorageURL: URL(fileURLWithPath: "/"),
            dataDbURL: URL(fileURLWithPath: "/"),
            torDirURL: URL(fileURLWithPath: "/"),
            endpoint: LightWalletEndpointBuilder.default,
            network: ZcashNetworkBuilder.network(for: networkType),
            spendParamsURL: URL(fileURLWithPath: "/"),
            outputParamsURL: URL(fileURLWithPath: "/"),
            saplingParamsSourceURL: .default
        )
    }()
    lazy var derivationTools: DerivationTool = { DerivationTool(networkType: networkType) }()
    let saplingAddress = SaplingAddress(validatedEncoding: "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6")
    let unifiedAddress = UnifiedAddress(
        validatedEncoding: """
        u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj
        """,
        networkType: .testnet
    )
    let transparentAddress = TransparentAddress(validatedEncoding: "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz")
    lazy var pendingTransactionEntity = {
        ZcashTransaction.Overview(
            accountUUID: TestsData.mockedAccountUUID,
            blockTime: nil,
            expiryHeight: nil,
            fee: Zatoshi(10000),
            index: nil,
            isShielding: false,
            hasChange: true,
            memoCount: 0,
            minedHeight: nil,
            raw: nil,
            rawID: Data(repeating: 1, count: 32),
            receivedNoteCount: 0,
            sentNoteCount: 0,
            value: Zatoshi(10),
            isExpiredUmined: false
        )
    }()

    let clearedTransaction = {
        ZcashTransaction.Overview(
            accountUUID: TestsData.mockedAccountUUID,
            blockTime: Date().timeIntervalSince1970,
            expiryHeight: 123000,
            fee: Zatoshi(10),
            index: nil,
            isShielding: false,
            hasChange: false,
            memoCount: 0,
            minedHeight: 120000,
            raw: nil,
            rawID: Data(repeating: 2, count: 32),
            receivedNoteCount: 0,
            sentNoteCount: 0,
            value: Zatoshi(100),
            isExpiredUmined: false
        )
    }()

    let sentTransaction = {
        ZcashTransaction.Overview(
            accountUUID: TestsData.mockedAccountUUID,
            blockTime: 1,
            expiryHeight: nil,
            fee: Zatoshi(10000),
            index: 0,
            isShielding: false,
            hasChange: true,
            memoCount: 0,
            minedHeight: 0,
            raw: nil,
            rawID: Data(repeating: 3, count: 32),
            receivedNoteCount: 0,
            sentNoteCount: 2,
            value: .zero,
            isExpiredUmined: false
        )
    }()

    let receivedTransaction = {
        ZcashTransaction.Overview(
            accountUUID: TestsData.mockedAccountUUID,
            blockTime: 1,
            expiryHeight: nil,
            fee: nil,
            index: 0,
            isShielding: false,
            hasChange: true,
            memoCount: 0,
            minedHeight: 0,
            raw: nil,
            rawID: Data(repeating: 4, count: 32),
            receivedNoteCount: 0,
            sentNoteCount: 2,
            value: .zero,
            isExpiredUmined: false
        )
    }()

    var seed: [UInt8] = Environment.seedBytes
    var spendingKey: UnifiedSpendingKey { try! derivationTools.deriveUnifiedSpendingKey(seed: seed, accountIndex: Zip32AccountIndex(0)) }
    var viewingKey: UnifiedFullViewingKey { try! derivationTools.deriveUnifiedFullViewingKey(from: spendingKey) }
    var birthday: BlockHeight = 123000

    init(networkType: NetworkType) {
        self.networkType = networkType
    }
}

extension TestsData {
    /// `mockedAccountUUID` is used to mock the rust backend for check only purposes. It's never passed to it.
    static let mockedAccountUUID = AccountUUID(id: [UInt8](repeating: 0, count: 16))
}
