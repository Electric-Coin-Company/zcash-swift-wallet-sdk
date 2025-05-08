//
//  TorRuntime.swift
//
//
//  Created by Jack Grigg on 04/06/2024.
//

import Foundation
import libzcashlc

public class TorClient {
    private let runtime: OpaquePointer
    public var cachedFiatCurrencyResult: FiatCurrencyResult?

    init(torDir: URL) throws {
        // Ensure that the directory exists.
        let fileManager = FileManager()
        if !fileManager.fileExists(atPath: torDir.path) {
            do {
                try fileManager.createDirectory(at: torDir, withIntermediateDirectories: true)
            } catch {
                throw ZcashError.blockRepositoryCreateBlocksCacheDirectory(torDir, error)
            }
        }

        let rawDir = torDir.osPathStr()
        let runtimePtr = zcashlc_create_tor_runtime(rawDir.0, rawDir.1)

        guard let runtimePtr else {
            throw ZcashError.rustTorClientInit(lastErrorMessage(fallback: "`TorClient` init failed with unknown error"))
        }

        runtime = runtimePtr
    }

    private init(runtimePtr: OpaquePointer) {
        runtime = runtimePtr
    }

    deinit {
        zcashlc_free_tor_runtime(runtime)
    }

    public func isolatedClient() throws -> TorClient {
        let isolatedPtr = zcashlc_tor_isolated_client(runtime)

        guard let isolatedPtr else {
            throw ZcashError.rustTorIsolatedClient(
                lastErrorMessage(fallback: "`TorClient.isolatedClient` failed with unknown error")
            )
        }

        return TorClient(runtimePtr: isolatedPtr)
    }

    public func getExchangeRateUSD() throws -> FiatCurrencyResult {
        let rate = zcashlc_get_exchange_rate_usd(runtime)

        if rate.is_sign_negative {
            throw ZcashError.rustTorClientGet(lastErrorMessage(fallback: "`TorClient.get` failed with unknown error"))
        }

        let newValue = FiatCurrencyResult(
            date: Date(),
            rate: NSDecimalNumber(
                mantissa: rate.mantissa,
                exponent: rate.exponent,
                isNegative: rate.is_sign_negative
            ),
            state: .success
        )

        cachedFiatCurrencyResult = newValue

        return newValue
    }

    public func connectToLightwalletd(endpoint: String) throws -> TorLwdConn {
        guard !endpoint.containsCStringNullBytesBeforeStringEnding() else {
            throw ZcashError.rustTorConnectToLightwalletd("endpoint string contains null bytes")
        }

        let lwdConnPtr = zcashlc_tor_connect_to_lightwalletd(
            runtime, [CChar](endpoint.utf8CString)
        )

        guard let lwdConnPtr else {
            throw ZcashError.rustTorConnectToLightwalletd(
                lastErrorMessage(fallback: "`TorClient.connectToLightwalletd` failed with unknown error")
            )
        }

        return TorLwdConn(connPtr: lwdConnPtr)
    }
}

public class TorLwdConn {
    private let conn: OpaquePointer

    // swiftlint:disable:next strict_fileprivate
    fileprivate init(connPtr: OpaquePointer) {
        conn = connPtr
    }

    deinit {
        zcashlc_free_tor_lwd_conn(conn)
    }

    /// Submits a raw transaction over lightwalletd.
    /// - Parameter spendTransaction: data representing the transaction to be sent
    /// - Throws: `serviceSubmitFailed` when GRPC call fails.
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        let success = zcashlc_tor_lwd_conn_submit_transaction(
            conn,
            spendTransaction.bytes,
            UInt(spendTransaction.count)
        )

        var response = SendResponse()
        
        if !success {
            let err = lastErrorMessage(fallback: "`TorLwdConn.submit` failed with unknown error")
            
            if err.hasPrefix("Failed to submit transaction (") && err.contains(")") {
                guard let startOfCode = err.firstIndex(of: "(") else {
                    throw ZcashError.rustTorLwdSubmit(err)
                }
                guard let endOfCode = err.firstIndex(of: ")") else {
                    throw ZcashError.rustTorLwdSubmit(err)
                }
                guard let errorCode = Int32(err[err.index(startOfCode, offsetBy: 1)..<endOfCode]) else {
                    throw ZcashError.rustTorLwdSubmit(err)
                }
                let errorMessage = String(err[err.index(endOfCode, offsetBy: 3)...])

                response.errorCode = errorCode
                response.errorMessage = errorMessage
            } else {
                throw ZcashError.rustTorLwdSubmit(err)
            }
        }
        
        return response
    }

    /// Gets a transaction by id
    /// - Parameter txId: data representing the transaction ID
    /// - Throws: LightWalletServiceError
    /// - Returns: LightWalletServiceResponse
    /// - Throws: `serviceFetchTransactionFailed` when GRPC call fails.
    func fetchTransaction(txId: Data) throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        guard txId.count == 32 else {
            throw ZcashError.rustGetMemoInvalidTxIdLength
        }

        var height: UInt64 = 0

        let txPtr = zcashlc_tor_lwd_conn_fetch_transaction(conn, txId.bytes, &height)

        guard let txPtr else {
            throw ZcashError.rustTorLwdFetchTransaction(
                lastErrorMessage(fallback: "`TorLwdConn.fetchTransaction` failed with unknown error")
            )
        }

        defer { zcashlc_free_boxed_slice(txPtr) }

        let isNotMined = height == 0 || height > UInt32.max

        return (
            tx:
                ZcashTransaction.Fetched(
                    rawID: txId,
                    minedHeight: isNotMined ? nil : UInt32(height),
                    raw: Data(
                        bytes: txPtr.pointee.ptr,
                        count: Int(txPtr.pointee.len)
                    )
                ),
            status: isNotMined ? .notInMainChain : .mined(Int(height))
        )
    }
    
    /// Gets a lightwalletd server info
    /// - Returns: LightWalletdInfo
    func getInfo() throws -> LightWalletdInfo {
        let infoPtr = zcashlc_tor_lwd_conn_get_info(conn)
        
        guard let infoPtr else {
            throw ZcashError.rustTorLwdGetInfo(
                lastErrorMessage(fallback: "`TorLwdConn.getInfo` failed with unknown error")
            )
        }
        
        defer { zcashlc_free_boxed_slice(infoPtr) }

        let slice = infoPtr.pointee
        guard let rawPtr = slice.ptr else {
            throw ZcashError.rustTorLwdGetInfo("`TorLwdConn.getInfo` Null pointer in FfiBoxedSlice")
        }
        
        let buffer = UnsafeBufferPointer<UInt8>(start: rawPtr, count: Int(slice.len))
        let data = Data(buffer: buffer)
        
        do {
            let info = try LightdInfo(serializedBytes: data)
            return info
        } catch {
            throw ZcashError.rustTorLwdGetInfo("`TorLwdConn.getInfo` Failed to decode protobuf LightdInfo: \(error)")
        }
    }

    /// Gets a chain tip of the blockchain (latest block height)
    /// - Returns: BlockHeight
    func latestBlockHeight() throws -> BlockHeight {
        var height: UInt32 = 0
        
        let blockIDPtr = zcashlc_tor_lwd_conn_latest_block(conn, &height)
        
        guard let blockIDPtr else {
            throw ZcashError.rustTorLwdLatestBlockHeight(
                lastErrorMessage(fallback: "`TorLwdConn.latestBlockHeight` failed with unknown error")
            )
        }
        
        defer { zcashlc_free_boxed_slice(blockIDPtr) }
        
        return BlockHeight(height)
    }
    
    /// Gets a tree state for a given height
    /// - Parameter height: heght for what a tree state is requested
    /// - Returns: TreeState
    func getTreeState(height: BlockHeight) throws -> TreeState {
        let treeStatePtr = zcashlc_tor_lwd_conn_get_tree_state(conn, UInt32(height))
        
        guard let treeStatePtr else {
            throw ZcashError.rustTorLwdGetTreeState(
                lastErrorMessage(fallback: "`TorLwdConn.getTreeState` failed with unknown error")
            )
        }
        
        defer { zcashlc_free_boxed_slice(treeStatePtr) }

        let slice = treeStatePtr.pointee
        guard let rawPtr = slice.ptr else {
            throw ZcashError.rustTorLwdGetTreeState("`TorLwdConn.getTreeState` Null pointer in FfiBoxedSlice")
        }
        
        let buffer = UnsafeBufferPointer<UInt8>(start: rawPtr, count: Int(slice.len))
        let data = Data(buffer: buffer)
        
        do {
            let treeState = try TreeState(serializedBytes: data)
            return treeState
        } catch {
            throw ZcashError.rustTorLwdGetTreeState("`TorLwdConn.getTreeState` Failed to decode protobuf TreeState: \(error)")
        }
    }
}
