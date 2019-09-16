//
//  ServiceHelper.swift
//  gRPC-PoC
//
//  Created by Francisco Gindre on 29/08/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC

class LightWalletGRPCService {
    
    let channel: Channel
    
    let compactTxStreamer: CompactTxStreamerServiceClient
    
    init(channel: Channel) {
        self.channel = channel
        compactTxStreamer = CompactTxStreamerServiceClient(channel: self.channel)
    }
    
    func blockRange(startHeight: UInt64, endHeight: UInt64? = nil,  result: @escaping (CallResult)->()) throws -> CompactTxStreamerGetBlockRangeCall {
           try compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight)) { result($0) }
    }
    
    func latestBlock() throws -> BlockID {
        try compactTxStreamer.getLatestBlock(ChainSpec())
    }
    
    func getTx(hash:String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)
        return try compactTxStreamer.getTransaction(filter)
    }
    
    func getAllBlocksSinceSaplingLaunch(_ result: @escaping (CallResult)->()) throws -> CompactTxStreamerGetBlockRangeCall {
        try compactTxStreamer.getBlockRange(BlockRange.sinceSaplingActivation(), completion: result)
    }
    
    
}

extension LightWalletGRPCService: LightWalletService {
    func latestBlockHeight(result: @escaping (Result<UInt64, LightWalletServiceError>) -> ()) {
        do {
            try compactTxStreamer.getLatestBlock(ChainSpec()) { (blockID, callResult) in
                guard let blockHeight = blockID?.height else {
                    result(.failure(LightWalletServiceError.generalError))
                    return
                }
                result(.success(blockHeight))
            }
        } catch {
            // TODO: Handle Error
            print(error.localizedDescription)
            result(.failure(LightWalletServiceError.generalError))
        }
    }
    
    func blockRange(_ range: Range<UInt64>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        result(.failure(LightWalletServiceError.generalError))
    }
    
    
}

extension LightWalletGRPCService: LightWalletSyncService {
    func latestBlockHeight() throws -> UInt64 {
        do {
            return try latestBlock().height
        } catch {
            // TODO: Specify error
            throw LightWalletServiceError.generalError
        }
    }
    
}
