//
//  AlternativeSynchronizerAPITestsData.swift
//
//
//  Created by Michal Fousek on 20.03.2023.
//

import Foundation
@testable import ZcashLightClientKit

class AlternativeSynchronizerAPITestsData {
    let initialier = Initializer(
        cacheDbURL: nil,
        fsBlockDbRoot: URL(fileURLWithPath: "/"),
        dataDbURL: URL(fileURLWithPath: "/"),
        pendingDbURL: URL(fileURLWithPath: "/"),
        endpoint: LightWalletEndpointBuilder.default,
        network: ZcashNetworkBuilder.network(for: .testnet),
        spendParamsURL: URL(fileURLWithPath: "/"),
        outputParamsURL: URL(fileURLWithPath: "/"),
        saplingParamsSourceURL: .default
    )
    lazy var derivationTools: DerivationTool = { initialier.makeDerivationTool() }()
    let saplingAddress = SaplingAddress(validatedEncoding: "ztestsapling1ctuamfer5xjnnrdr3xdazenljx0mu0gutcf9u9e74tr2d3jwjnt0qllzxaplu54hgc2tyjdc2p6")
    let unifiedAddress = UnifiedAddress(
        validatedEncoding: """
        u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj
        """
    )
    let transparentAddress = TransparentAddress(validatedEncoding: "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz")
    lazy var pendingTransactionEntity = {
        PendingTransaction(value: Zatoshi(10), recipient: .address(.transparent(transparentAddress)), memo: .empty(), account: 0)
    }()

    let clearedTransaction = {
        ZcashTransaction.Overview(
            blockTime: Date().timeIntervalSince1970,
            expiryHeight: 123000,
            fee: Zatoshi(10),
            id: 333,
            index: nil,
            isWalletInternal: false,
            hasChange: false,
            memoCount: 0,
            minedHeight: 120000,
            raw: nil,
            rawID: Data(),
            receivedNoteCount: 0,
            sentNoteCount: 0,
            value: Zatoshi(100)
        )
    }()

    let sentTransaction = {
        ZcashTransaction.Sent(
            blockTime: 1,
            expiryHeight: nil,
            fromAccount: 0,
            id: 9,
            index: 0,
            memoCount: 0,
            minedHeight: 0,
            noteCount: 0,
            raw: nil,
            rawID: nil,
            value: Zatoshi.zero
        )
    }()

    let receivedTransaction = {
        ZcashTransaction.Received(
            blockTime: 1,
            expiryHeight: nil,
            fromAccount: 0,
            id: 9,
            index: 0,
            memoCount: 0,
            minedHeight: 0,
            noteCount: 0,
            raw: nil,
            rawID: nil,
            value: Zatoshi.zero
        )
    }()

    var seed: [UInt8] = Environment.seedBytes
    var spendingKey: UnifiedSpendingKey {
        get async {
            try! await derivationTools.deriveUnifiedSpendingKey(seed: seed, accountIndex: 0)
        }
    }
    var viewingKey: UnifiedFullViewingKey {
        get async {
            try! await derivationTools.deriveUnifiedFullViewingKey(from: spendingKey)
        }
    }
    var birthday: BlockHeight = 123000

    init() { }
}
