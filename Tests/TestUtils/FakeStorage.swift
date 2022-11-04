//
//  FakeStorage.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
@testable import ZcashLightClientKit

class ZcashConsoleFakeStorage: CompactBlockRepository {
    func latestHeightAsync() async throws -> BlockHeight {
        latestBlockHeight
    }
    
    func write(blocks: [ZcashCompactBlock]) async throws {
        fakeSave(blocks: blocks)
    }
    
    func rewindAsync(to height: BlockHeight) async throws {
        fakeRewind(to: height)
    }
    
    func latestHeight() throws -> Int {
        return self.latestBlockHeight
    }

    func latestBlock() throws -> ZcashLightClientKit.ZcashCompactBlock {
        return ZcashCompactBlock(height: latestBlockHeight, data: Data())
    }

    func rewind(to height: BlockHeight) throws {
        fakeRewind(to: height)
    }
    
    var latestBlockHeight: BlockHeight = 0
    var delay = DispatchTimeInterval.milliseconds(300)
    
    init(latestBlockHeight: BlockHeight = 0) {
        self.latestBlockHeight = latestBlockHeight
    }
    
    private func fakeSave(blocks: [ZcashCompactBlock]) {
        blocks.forEach {
            LoggerProxy.debug("saving block \($0)")
            self.latestBlockHeight = $0.height
        }
    }
    
    private func fakeRewind(to height: BlockHeight) {
        LoggerProxy.debug("rewind to \(height)")
        self.latestBlockHeight = min(self.latestBlockHeight, height)
    }
}
