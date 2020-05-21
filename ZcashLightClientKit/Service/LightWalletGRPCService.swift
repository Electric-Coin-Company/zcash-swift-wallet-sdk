//
//  ServiceHelper.swift
//  gRPC-PoC
//
//  Created by Francisco Gindre on 29/08/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import NIO
public typealias Channel = GRPC.GRPCChannel

/**
 Swift GRPC implementation of Lightwalletd service */
public class LightWalletGRPCService {
    
    var queue = DispatchQueue.init(label: "LightWalletGRPCService")
    let channel: Channel
    
    let compactTxStreamer: CompactTxStreamerClient
    
    public init(channel: Channel) {
        self.channel = channel
        compactTxStreamer = CompactTxStreamerClient(channel: self.channel)
    }
    
    public convenience init(endpoint: LightWalletEndpoint) {
        self.init(host: endpoint.host, port: endpoint.port, secure: endpoint.secure)
    }
    
    public convenience init(host: String, port: Int = 9067, secure: Bool = true) {
        let configuration = ClientConnection.Configuration(target: .hostAndPort(host, port), eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1), tls: secure ? .init() : nil)
        let channel = ClientConnection(configuration: configuration)
        self.init(channel: channel)
    }
    
    func stop() {
        _ = channel.close()
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil, result: @escaping (CompactBlock) -> Void) throws -> ServerStreamingCall<BlockRange, CompactBlock> {
        compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight), handler: result)
    }
    
    func latestBlock() throws -> BlockID {
        try compactTxStreamer.getLatestBlock(ChainSpec()).response.wait()
    }
    
    func getTx(hash: String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)
        return try compactTxStreamer.getTransaction(filter).response.wait()
    }
    
}

extension LightWalletGRPCService: LightWalletService {
    public func fetchTransaction(txId: Data) throws -> TransactionEntity {
        var txFilter = TxFilter()
        txFilter.hash = txId
        let rawTx = try compactTxStreamer.getTransaction(txFilter).response.wait()
        
        return TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)
    }
    
    public func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        compactTxStreamer.getTransaction(txFilter).response.whenComplete({ response in
            
            switch response {
            case .failure(let error):
                result(.failure(LightWalletServiceError.genericError(error: error)))
            case .success(let rawTx):
                result(.success(TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)))
            }
        })
    }
    
    public func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        do {
            let tx = try RawTransaction(serializedData: spendTransaction)
            let response = self.compactTxStreamer.sendTransaction(tx).response
            
            response.whenComplete { (responseResult) in
                switch responseResult {
                case .failure(let e):
                    result(.failure(LightWalletServiceError.genericError(error: e)))
                case .success(let s):
                    result(.success(s))
                }
            }
        } catch {
            result(.failure(LightWalletServiceError.genericError(error: error)))
        }
    }
    
    public func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        
        let rawTx = RawTransaction.with { (raw) in
            raw.data = spendTransaction
        }
        return try compactTxStreamer.sendTransaction(rawTx).response.wait()
    }
    
    public func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        var blocks = [CompactBlock]()
        
        let response = compactTxStreamer.getBlockRange(range.blockRange(), handler: {
            blocks.append($0)
        })
        
        do {
            _ = try response.status.wait()
        } catch {
            throw LightWalletServiceError.genericError(error: error)
        }
        
        do {
            return try blocks.asZcashCompactBlocks()
        } catch {
            LoggerProxy.error("invalid block in range: \(range) - Error: \(error)")
            throw LightWalletServiceError.genericError(error: error)
        }
    }
    
    public func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        let response = compactTxStreamer.getLatestBlock(ChainSpec()).response
        
        response.whenSuccess { (blockID) in
            guard let blockHeight = Int(exactly: blockID.height) else {
                result(.failure(LightWalletServiceError.generalError))
                return
            }
            result(.success(blockHeight))
        }
        
        response.whenFailure { (error) in
            result(.failure(LightWalletServiceError.genericError(error: error)))
        }
        
    }
    
    // TODO: Make cancellable
    public func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {

        queue.async { [weak self] in
            
            guard let self = self else { return }
            
            var blocks = [CompactBlock]()
            
            let response = self.compactTxStreamer.getBlockRange(range.blockRange(), handler: { blocks.append($0) })
            
            do {
                let status = try response.status.wait()
                switch status.code {
                case .ok:
                    do {
                        result(.success(try blocks.asZcashCompactBlocks()))
                    } catch {
                        result(.failure(LightWalletServiceError.generalError))
                    }
                    
                default:
                    result(Result.failure(LightWalletServiceError.failed(statusCode: status.code.rawValue, message: status.message ?? "No Message")))
                }
                
            } catch {
                result(.failure(LightWalletServiceError.genericError(error: error)))
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
