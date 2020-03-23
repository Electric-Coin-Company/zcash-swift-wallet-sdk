//
//  DarkSideWalletService.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import Foundation
import ZcashLightClientKit

class DarksideWalletService: LightWalletService {
    
    var service = LightWalletGRPCService(channel: ChannelProvider().channel())
    
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        service.latestBlockHeight(result: result)
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        try service.latestBlockHeight()
    }
    
    func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        service.blockRange(range, result: result)
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        try service.blockRange(range)
    }
    
    func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        service.submit(spendTransaction: spendTransaction, result: result)
    }
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        try service.submit(spendTransaction: spendTransaction)
    }
    
    func triggerReOrg() {}
    
    
}
