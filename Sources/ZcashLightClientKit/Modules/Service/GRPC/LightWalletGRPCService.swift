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
import NIOHPACK
import NIOTransportServices

typealias Channel = GRPC.GRPCChannel

extension LightdInfo: LightWalletdInfo {}
extension SendResponse: LightWalletServiceResponse {}

/**
Swift GRPC implementation of Lightwalletd service
*/
enum GRPCResult: Equatable {
    case success
    case error(_ error: LightWalletServiceError)
}

protocol CancellableCall {
    func cancel()
}

extension ServerStreamingCall: CancellableCall {
    func cancel() {
        self.cancel(promise: self.eventLoop.makePromise(of: Void.self))
    }
}

protocol LatestBlockHeightProvider {
    func latestBlockHeight(streamer: CompactTxStreamerNIOClient?) throws -> BlockHeight
}

class LiveLatestBlockHeightProvider: LatestBlockHeightProvider {
    func latestBlockHeight(streamer: CompactTxStreamerNIOClient?) throws -> BlockHeight {
        do {
            guard let height = try? streamer?.getLatestBlock(ChainSpec()).response.wait().compactBlockHeight() else {
                throw LightWalletServiceError.timeOut
            }
            return height
        } catch {
            throw error.mapToServiceError()
        }
    }
}

class LightWalletGRPCService {
    let channel: Channel
    let connectionManager: ConnectionStatusManager
    let compactTxStreamer: CompactTxStreamerNIOClient
    let compactTxStreamerAsync: CompactTxStreamerAsyncClient
    let singleCallTimeout: TimeLimit
    let streamingCallTimeout: TimeLimit
    var latestBlockHeightProvider: LatestBlockHeightProvider = LiveLatestBlockHeightProvider()

    var connectionStateChange: ((_ from: ConnectionState, _ to: ConnectionState) -> Void)? {
        get { connectionManager.connectionStateChange }
        set { connectionManager.connectionStateChange = newValue }
    }

    var queue: DispatchQueue
    
    convenience init(endpoint: LightWalletEndpoint) {
        self.init(
            host: endpoint.host,
            port: endpoint.port,
            secure: endpoint.secure,
            singleCallTimeout: endpoint.singleCallTimeoutInMillis,
            streamingCallTimeout: endpoint.streamingCallTimeoutInMillis
        )
    }

    /// Inits a connection to a Lightwalletd service to the given
    /// - Parameters:
    ///  - host: the hostname of the lightwalletd server
    ///  - port: port of the server. Default is 9067
    ///  - secure: whether this server is TLS or plaintext. default True (TLS)
    ///  - singleCallTimeout: Timeout for unary calls in milliseconds.
    ///  - streamingCallTimeout: Timeout for streaming calls in milliseconds.
    init(
        host: String,
        port: Int = 9067,
        secure: Bool = true,
        singleCallTimeout: Int64,
        streamingCallTimeout: Int64
    ) {
        self.connectionManager = ConnectionStatusManager()
        self.queue = DispatchQueue.init(label: "LightWalletGRPCService")
        self.streamingCallTimeout = TimeLimit.timeout(.milliseconds(streamingCallTimeout))
        self.singleCallTimeout = TimeLimit.timeout(.milliseconds(singleCallTimeout))

        let connectionBuilder = secure ?
        ClientConnection.usingPlatformAppropriateTLS(for: NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default)) :
        ClientConnection.insecure(group: NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default))

        let channel = connectionBuilder
            .withConnectivityStateDelegate(connectionManager, executingOn: queue)
            .connect(host: host, port: port)

        self.channel = channel

        compactTxStreamer = CompactTxStreamerNIOClient(
            channel: self.channel,
            defaultCallOptions: Self.callOptions(
                timeLimit: self.singleCallTimeout
            )
        )
        
        compactTxStreamerAsync = CompactTxStreamerAsyncClient(
            channel: self.channel,
            defaultCallOptions: Self.callOptions(
                timeLimit: self.singleCallTimeout
            )
        )
    }

    deinit {
        _ = channel.close()
        _ = compactTxStreamer.channel.close()
        _ = compactTxStreamerAsync.channel.close()
    }

    func stop() {
        _ = channel.close()
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil, result: @escaping (CompactBlock) -> Void) -> ServerStreamingCall<BlockRange, CompactBlock> {
        compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight), handler: result)
    }

    func latestBlock() throws -> BlockID {
        do {
            return try compactTxStreamer.getLatestBlock(ChainSpec()).response.wait()
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    func getTx(hash: String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)

        do {
            return try compactTxStreamer.getTransaction(filter).response.wait()
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    static func callOptions(timeLimit: TimeLimit) -> CallOptions {
        CallOptions(
            customMetadata: HPACKHeaders(),
            timeLimit: timeLimit,
            messageEncoding: .disabled,
            requestIDProvider: .autogenerated,
            requestIDHeader: nil,
            cacheable: false
        )
    }
}

// MARK: - LightWalletService

extension LightWalletGRPCService: LightWalletService {
    func getInfo() async throws -> LightWalletdInfo {
        do {
            return try await compactTxStreamerAsync.getLightdInfo(Empty())
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        do {
            return try latestBlockHeightProvider.latestBlockHeight(streamer: compactTxStreamer)
        } catch {
            throw error.mapToServiceError()
        }
    }

    func latestBlockHeightAsync() async throws -> BlockHeight {
        do {
            let blockID = try await compactTxStreamerAsync.getLatestBlock(ChainSpec())
            guard let blockHeight = Int(exactly: blockID.height) else {
                throw LightWalletServiceError.generalError(message: "error creating blockheight from BlockID \(blockID)")
            }
            return blockHeight
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        let stream = compactTxStreamerAsync.getBlockRange(range.blockRange())

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await block in stream {
                        continuation.yield(ZcashCompactBlock(compactBlock: block))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error.mapToServiceError())
                }
            }
        }
    }
    
    func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        do {
            let transaction = RawTransaction.with { $0.data = spendTransaction }
            return try await compactTxStreamerAsync.sendTransaction(transaction)
        } catch {
            throw LightWalletServiceError.sentFailed(error: error)
        }
    }
    
    func fetchTransaction(txId: Data) async throws -> ZcashTransaction.Fetched {
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        do {
            let rawTx = try await compactTxStreamerAsync.getTransaction(txFilter)
            return ZcashTransaction.Fetched(rawID: txId, minedHeight: BlockHeight(rawTx.height), raw: rawTx.data)
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    func fetchUTXOs(
        for tAddress: String,
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>
        ) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            let arg = GetAddressUtxosArg.with { utxoArgs in
                utxoArgs.addresses = [tAddress]
                utxoArgs.startHeight = UInt64(height)
            }
            var utxos: [UnspentTransactionOutputEntity] = []
            let response = self.compactTxStreamer.getAddressUtxosStream(arg) { reply in
                utxos.append(
                    UTXO(
                        id: nil,
                        address: tAddress,
                        prevoutTxId: reply.txid,
                        prevoutIndex: Int(reply.index),
                        script: reply.script,
                        valueZat: Int(reply.valueZat),
                        height: Int(reply.height),
                        spentInTx: nil
                    )
                )
            }
            
            do {
                let status = try response.status.wait()
                switch status.code {
                case .ok:
                    result(.success(utxos))
                default:
                    result(.failure(.mapCode(status)))
                }
            } catch {
                result(.failure(error.mapToServiceError()))
            }
        }
    }
    
    func fetchUTXOs(
        for tAddress: String,
        height: BlockHeight
    ) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        return fetchUTXOs(for: [tAddress], height: height)
    }

    func fetchUTXOs(
        for tAddresses: [String],
        height: BlockHeight
    ) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        guard !tAddresses.isEmpty else {
            return AsyncThrowingStream { continuation in continuation.finish() }
        }
        
        let args = GetAddressUtxosArg.with { utxoArgs in
            utxoArgs.addresses = tAddresses
            utxoArgs.startHeight = UInt64(height)
        }
        let stream = compactTxStreamerAsync.getAddressUtxosStream(args)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await reply in stream {
                        continuation.yield(
                            UTXO(
                                id: nil,
                                address: reply.address,
                                prevoutTxId: reply.txid,
                                prevoutIndex: Int(reply.index),
                                script: reply.script,
                                valueZat: Int(reply.valueZat),
                                height: Int(reply.height),
                                spentInTx: nil
                            )
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error.mapToServiceError())
                }
            }
        }
    }
    
    func blockStream(
        startHeight: BlockHeight,
        endHeight: BlockHeight
    ) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        let stream = compactTxStreamerAsync.getBlockRange(
            BlockRange(
                startHeight: startHeight,
                endHeight: endHeight
            ),
            callOptions: Self.callOptions(timeLimit: self.streamingCallTimeout)
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await compactBlock in stream {
                        continuation.yield(ZcashCompactBlock(compactBlock: compactBlock))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error.mapToServiceError())
                }
            }
        }
    }

    func closeConnection() {
        _ = channel.close()
    }
}

// MARK: - Extensions

extension ConnectivityState {
    func toConnectionState() -> ConnectionState {
        switch self {
        case .connecting:
            return .connecting
        case .idle:
            return .idle
        case .ready:
            return .online
        case .shutdown:
            return .shutdown
        case .transientFailure:
            return .reconnecting
        }
    }
}

extension TimeAmount {
    static let singleCallTimeout = TimeAmount.seconds(30)
    static let streamingCallTimeout = TimeAmount.minutes(10)
}

extension CallOptions {
    static var lwdCall: CallOptions {
        CallOptions(
            customMetadata: HPACKHeaders(),
            timeLimit: .timeout(.singleCallTimeout),
            messageEncoding: .disabled,
            requestIDProvider: .autogenerated,
            requestIDHeader: nil,
            cacheable: false
        )
    }
}

extension Error {
    func mapToServiceError() -> LightWalletServiceError {
        guard let grpcError = self as? GRPCStatusTransformable else {
            return LightWalletServiceError.genericError(error: self)
        }
        
        return LightWalletServiceError.mapCode(grpcError.makeGRPCStatus())
    }
}

extension LightWalletServiceError {
    static func mapCode(_ status: GRPCStatus) -> LightWalletServiceError {
        switch status.code {
        case .ok:
            return LightWalletServiceError.unknown
        case .cancelled:
            return LightWalletServiceError.userCancelled
        case .unknown:
            return LightWalletServiceError.generalError(message: status.message ?? "GRPC unknown error contains no message")
        case .deadlineExceeded:
            return LightWalletServiceError.timeOut
        default:
            return LightWalletServiceError.genericError(error: status)
        }
    }
}

class ConnectionStatusManager: ConnectivityStateDelegate {
    var connectionStateChange: ((_ from: ConnectionState, _ to: ConnectionState) -> Void)?
    init() { }

    func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        connectionStateChange?(oldState.toConnectionState(), newState.toConnectionState())
    }
}
