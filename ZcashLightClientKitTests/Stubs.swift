//
//  Stubs.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import ZcashLightClientKit

class AwfulLightWalletService: LightWalletService {
    func latestBlockHeight() throws -> BlockHeight {
        throw LightWalletServiceError.generalError
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        throw LightWalletServiceError.invalidBlock
    }
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.generalError))
        }
        
    }
    
    func blockRange(_ range: Range<BlockHeight>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result(.failure(LightWalletServiceError.generalError))
        }
    }
    
    
}
