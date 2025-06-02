//
//  LightWalletGRPCServiceOverTor.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-04-08.
//

import Foundation

class LightWalletGRPCServiceOverTor: LightWalletGRPCService {
    var tor: TorClient?
    var endpointString: String?
    
    convenience init(endpoint: LightWalletEndpoint, tor: TorClient?) {
        self.init(
            host: endpoint.host,
            port: endpoint.port,
            secure: endpoint.secure,
            singleCallTimeout: endpoint.singleCallTimeoutInMillis,
            streamingCallTimeout: endpoint.streamingCallTimeoutInMillis,
            tor: tor
        )
    }
    
    init(
        host: String,
        port: Int,
        secure: Bool,
        singleCallTimeout: Int64,
        streamingCallTimeout: Int64,
        tor: TorClient?
    ) {
        self.tor = tor
        endpointString = String(format: "%@://%@:%d", secure ? "https" : "http", host, port)
        
        super.init(
            host: host,
            port: port,
            secure: secure,
            singleCallTimeout: singleCallTimeout,
            streamingCallTimeout: streamingCallTimeout
        )
    }
    
    func connectToLightwalletd() throws -> TorLwdConn {
        guard let endpointString else {
            throw ZcashError.torServiceMissingEndpoint
        }
        
        guard let tor else {
            throw ZcashError.torServiceMissingTorClient
        }
        
        return try tor.connectToLightwalletd(endpoint: endpointString)
    }

    override func getInfo() async throws -> LightWalletdInfo {
        try connectToLightwalletd().getInfo()
    }

    override func latestBlockHeight() async throws -> BlockHeight {
        BlockHeight(try await latestBlock().height)
    }

    override func latestBlock() async throws -> BlockID {
        try connectToLightwalletd().latestBlock()
    }
    
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        try connectToLightwalletd().submit(spendTransaction: spendTransaction)
    }
    
    override func fetchTransaction(txId: Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        try connectToLightwalletd().fetchTransaction(txId: txId)
    }
    
    override func getTreeState(_ id: BlockID) async throws -> TreeState {
        try connectToLightwalletd().getTreeState(height: BlockHeight(id.height))
    }
}
