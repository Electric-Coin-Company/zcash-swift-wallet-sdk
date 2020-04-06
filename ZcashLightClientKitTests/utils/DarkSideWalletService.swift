//
//  DarkSideWalletService.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import Foundation
import ZcashLightClientKit
import SwiftGRPC
class DarksideWalletService: LightWalletService {
    var channel: Channel
    init() {
        let channel = ChannelProvider().channel()
        self.channel = channel
        self.service = LightWalletGRPCService(channel: channel)
        self.darksideService = DarksideStreamerServiceClient(channel: channel)
    }
    var service: LightWalletGRPCService
    var darksideService: DarksideStreamerServiceClient
    
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
    
    func triggerReOrg(latestHeight: BlockHeight, reOrgHeight: BlockHeight) throws {
        var darksideState = DarksideState()
        darksideState.latestHeight = UInt64(latestHeight)
        darksideState.reorgHeight = UInt64(reOrgHeight)
        
       _ = try darksideService.darksideSetState(darksideState, metadata: Metadata())
    }
    
    func setLatestHeight(_ latestHeight: BlockHeight) throws {
        var state = DarksideState()
        state.reorgHeight = 0
        state.latestHeight = UInt64(latestHeight)
        _ = try darksideService.darksideSetState(state, metadata: Metadata())
    }
    
    
}
