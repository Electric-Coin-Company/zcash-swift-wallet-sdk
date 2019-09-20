//
//  Storage.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation


class ZcashConsoleFakeStorage: CompactBlockAsyncStoring {
    
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
    
    func write(blocks: [ZcashCompactBlock], completion: ((Error?) -> Void)?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            blocks.forEach {
                print("saving block \($0)")
                self.latestBlockHeight = $0.height
            }
            completion?(nil)
        }
    }
    
    func rewind(to height: BlockHeight, completion: ((Error?) -> Void)?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("rewind to \(height)")
            self.latestBlockHeight = min(self.latestBlockHeight, height)
            completion?(nil)
        }
    }
    
    
    
}
