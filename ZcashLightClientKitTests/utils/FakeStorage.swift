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
    func latestHeight() throws -> Int {
        return self.latestBlockHeight
    }
    
    func write(blocks: [ZcashCompactBlock]) throws {
        fakeSave(blocks: blocks)
    }
    
    func rewind(to height: BlockHeight) throws {
        fakeRewind(to: height)
    }
    
    var latestBlockHeight: BlockHeight = 0
    var delay = DispatchTimeInterval.milliseconds(300)
    
    init(latestBlockHeight: BlockHeight = 0) {
        self.latestBlockHeight = latestBlockHeight
    }
    
    func latestHeight(result: @escaping (Result<BlockHeight, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            result(.success(self.latestBlockHeight))
        }
    }
    
    fileprivate func fakeSave(blocks: [ZcashCompactBlock]) {
        blocks.forEach {
            LoggerProxy.debug("saving block \($0)")
            self.latestBlockHeight = $0.height
        }
    }
    
    func write(blocks: [ZcashCompactBlock], completion: ((Error?) -> Void)?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.fakeSave(blocks: blocks)
            completion?(nil)
        }
    }
    
    func rewind(to height: BlockHeight, completion: ((Error?) -> Void)?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.fakeRewind(to: height)
            completion?(nil)
        }
    }
    
    private func fakeRewind(to height: BlockHeight) {
        LoggerProxy.debug("rewind to \(height)")
        self.latestBlockHeight = min(self.latestBlockHeight, height)
    }
    
}
