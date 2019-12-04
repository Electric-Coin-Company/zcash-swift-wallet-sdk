//
//  ServiceHelper.swift
//  gRPC-PoC
//
//  Created by Francisco Gindre on 29/08/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC

public class LightWalletGRPCService {
    
    var queue = DispatchQueue.init(label: "LightWalletGRPCService")
    let channel: Channel
    
    let compactTxStreamer: CompactTxStreamerServiceClient
    
    public init(channel: Channel) {
        self.channel = channel
        compactTxStreamer = CompactTxStreamerServiceClient(channel: self.channel)
    }
    
    public convenience init(endpoint: LightWalletEndpoint) {
        self.init(host: endpoint.host, secure: endpoint.secure)
    }
    
    public convenience init(host: String, secure: Bool = true) {
        let channel = Channel(address: host, secure: secure, arguments: [])
        self.init(channel: channel)
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil, result: @escaping (CallResult) -> Void) throws -> CompactTxStreamerGetBlockRangeCall {
        try compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight)) { result($0) }
    }
    
    func latestBlock() throws -> BlockID {
        try compactTxStreamer.getLatestBlock(ChainSpec())
    }
    
    func getTx(hash: String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)
        return try compactTxStreamer.getTransaction(filter)
    }
    
    func getAllBlocksSinceSaplingLaunch(_ result: @escaping (CallResult) -> Void) throws -> CompactTxStreamerGetBlockRangeCall {
        try compactTxStreamer.getBlockRange(BlockRange.sinceSaplingActivation(), completion: result)
    }
    
}

extension LightWalletGRPCService: LightWalletService {
    public func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            guard let self = self else { return }
            
            do {
                let response = try self.compactTxStreamer.sendTransaction(RawTransaction(serializedData: spendTransaction))
                result(.success(response))
            } catch {
                result(.failure(LightWalletServiceError.genericError(error: error)))
            }
        }
    }
    
    public func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        try compactTxStreamer.sendTransaction(RawTransaction(serializedData: spendTransaction))
    }
    
    public func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        var blocks = [ZcashCompactBlock]()
        
        let call = try compactTxStreamer.getBlockRange(range.blockRange(), completion: { statusCode in
            print("finished with statusCode: \(statusCode)")
        })
        
        while let block = try call.receive() {
            
            if let compactBlock = ZcashCompactBlock(compactBlock: block) {
                blocks.append(compactBlock)
            } else {
                throw LightWalletServiceError.invalidBlock
            }
        }
        
        return blocks
    }
    
    public func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        do {
            try compactTxStreamer.getLatestBlock(ChainSpec()) { (blockID, _) in
                guard let rawHeight = blockID?.height, let blockHeight = Int(exactly: rawHeight) else {
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
    public func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        
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
    
    public func latestBlockHeight() throws -> BlockHeight {
        
        guard let height = try? latestBlock().compactBlockHeight() else {
            throw LightWalletServiceError.invalidBlock
        }
        return height
    }
    
}
