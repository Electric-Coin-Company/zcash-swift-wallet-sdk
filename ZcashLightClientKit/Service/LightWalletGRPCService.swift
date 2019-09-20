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
    
    var queue = DispatchQueue.init(label: "LightWalletGRPCService")
    let channel: Channel
    
    let compactTxStreamer: CompactTxStreamerServiceClient
    
    init(channel: Channel) {
        self.channel = channel
        compactTxStreamer = CompactTxStreamerServiceClient(channel: self.channel)
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil,  result: @escaping (CallResult)->()) throws -> CompactTxStreamerGetBlockRangeCall {
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
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> ()) {
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
    
    // TODO: Make cancellable
    func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        
        
        queue.async {
            var blocks = [CompactBlock]()
            var isSyncing = true
            guard let response = try? self.compactTxStreamer.getBlockRange(range.blockRange(),completion: { (callResult) in
                isSyncing = false
                if callResult.success {
                    let code = callResult.statusCode
                    switch code{
                    case .ok:
                        do {
                            result(.success(try blocks.asZcashCompactBlocks()))
                        } catch {
                            result(.failure(LightWalletServiceError.generalError))
                        }
                    default:
                        result(.failure(LightWalletServiceError.failed(statusCode: code)))
                    }
                    
                    
                } else {
                    result(.failure(LightWalletServiceError.generalError))
                    return
                }
            }) else {
                result(.failure(LightWalletServiceError.generalError))
                return
            }
            do {
                
                var element: CompactBlock?
                repeat {
                    element = try response.receive()
                    if let e = element {
                        blocks.append(e)
                    }
                } while isSyncing && element != nil
                
            } catch {
                result(.failure(LightWalletServiceError.generalError))
            }
        }
        
    }
    
}



extension LightWalletGRPCService: LightWalletSyncService {
    func latestBlockHeight() throws -> BlockHeight {
        do {
            return try latestBlock().height
        } catch {
            // TODO: Specify error
            throw LightWalletServiceError.generalError
        }
    }
    
}
