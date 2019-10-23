//
//  FakeService.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/23/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
@testable import ZcashLightClientKit
class MockLightWalletService: LightWalletService {
    
    private var service = LightWalletGRPCService(channel: ChannelProvider().channel())
    private var latestHeight: BlockHeight
    
    init(latestBlockHeight: BlockHeight) {
        self.latestHeight = latestBlockHeight
    }
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            result(.success(self.latestHeight))
        }
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        return self.latestHeight
    }
    
    func blockRange(_ range: Range<BlockHeight>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        self.service.blockRange(range, result: result)
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        try self.service.blockRange(range)
    }
    
    
}
