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
    var groups: [String: TorLwdConn] = [:]
    var defaultTorLwdConn: TorLwdConn?
    
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
    
    func connectToLightwalletd(_ mode: ServiceMode) throws -> TorLwdConn {
        guard let endpointString else {
            throw ZcashError.torServiceMissingEndpoint
        }
        
        guard let tor else {
            throw ZcashError.torServiceMissingTorClient
        }
        
        // defaultTor
        if mode == .defaultTor {
            if defaultTorLwdConn == nil {
                defaultTorLwdConn = try tor.connectToLightwalletd(endpoint: endpointString)
            }
            
            guard let defaultTorLwdConn else {
                throw ZcashError.torServiceUnableToCreateDefaultTorLwdConn
            }
            
            return defaultTorLwdConn
        } else if case let .torInGroup(groupName) = mode {
            // torInGroup
            guard let torInGroup = groups[groupName] else {
                let torInGroupNamed = try tor.connectToLightwalletd(endpoint: endpointString)
                
                groups[groupName] = torInGroupNamed
                
                return torInGroupNamed
            }
            
            return torInGroup
        } else {
            throw ZcashError.torServiceUnresolvedMode
        }
    }

    override func getInfo(mode: ServiceMode) async throws -> LightWalletdInfo {
        guard mode != .direct else {
            return try await super.getInfo(mode: mode)
        }
        
        return try connectToLightwalletd(mode).getInfo()
    }

    override func latestBlockHeight(mode: ServiceMode) async throws -> BlockHeight {
        guard mode != .direct else {
            return try await super.latestBlockHeight(mode: mode)
        }

        return BlockHeight(try await latestBlock(mode: .defaultTor).height)
    }

    override func latestBlock(mode: ServiceMode) async throws -> BlockID {
        guard mode != .direct else {
            return try await super.latestBlock(mode: mode)
        }

        return try connectToLightwalletd(mode).latestBlock()
    }
    
    override func submit(spendTransaction: Data, mode: ServiceMode) async throws -> LightWalletServiceResponse {
        guard mode != .direct else {
            return try await super.submit(spendTransaction: spendTransaction, mode: mode)
        }

        return try connectToLightwalletd(mode).submit(spendTransaction: spendTransaction)
    }
    
    override func fetchTransaction(txId: Data, mode: ServiceMode) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        guard mode != .direct else {
            return try await super.fetchTransaction(txId: txId, mode: mode)
        }

        return try connectToLightwalletd(mode).fetchTransaction(txId: txId)
    }
    
    override func getTreeState(_ id: BlockID, mode: ServiceMode) async throws -> TreeState {
        guard mode != .direct else {
            return try await super.getTreeState(id, mode: mode)
        }

        return try connectToLightwalletd(mode).getTreeState(height: BlockHeight(id.height))
    }
}
