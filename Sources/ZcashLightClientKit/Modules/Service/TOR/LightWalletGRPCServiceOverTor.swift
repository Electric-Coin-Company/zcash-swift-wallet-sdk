//
//  LightWalletTORServiceOverTor.swift
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
    
    func connectToLightwalletd() -> TorLwdConn? {
        guard let endpointString else {
            return nil
        }
        
        return try? tor?.connectToLightwalletd(endpoint: endpointString)
    }
    
    func randomDelay() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64.random(in: 1...3))
    }
    
    override func getInfo() async throws -> LightWalletdInfo {
        guard let torConn = connectToLightwalletd() else {
            throw
        }

        return try torConn.getInfo()
    }
    
    override func latestBlockHeight() async throws -> BlockHeight {
        guard let torConn = connectToLightwalletd() else {
            await randomDelay()
            return try await super.latestBlockHeight()
        }
        
        do {
            return try torConn.latestBlockHeight()
        } catch {
            await randomDelay()
            return try await super.latestBlockHeight()
        }
    }
    
    override func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        guard let torConn = connectToLightwalletd() else {
            await randomDelay()
            return try await super.submit(spendTransaction: spendTransaction)
        }
        
        do {
            return try torConn.submit(spendTransaction: spendTransaction)
        } catch {
            await randomDelay()
            return try await super.submit(spendTransaction: spendTransaction)
        }
    }
    
    override func fetchTransaction(txId: Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        guard let torConn = connectToLightwalletd() else {
            await randomDelay()
            return try await super.fetchTransaction(txId: txId)
        }
        
        do {
            return try torConn.fetchTransaction(txId: txId)
        } catch {
            await randomDelay()
            return try await super.fetchTransaction(txId: txId)
        }
    }
    
    override func getTreeState(_ id: BlockID) async throws -> TreeState {
        guard let torConn = connectToLightwalletd() else {
            await randomDelay()
            return try await super.getTreeState(id)
        }
        
        do {
            return try torConn.getTreeState(height: BlockHeight(id.height))
        } catch {
            await randomDelay()
            return try await super.getTreeState(id)
        }
    }
}
