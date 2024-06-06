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

    init(torDir: URL) async throws {
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

    deinit {
        zcashlc_free_tor_runtime(runtime)
    }

    public func getExchangeRateUSD() async throws -> NSDecimalNumber {
        let rate = zcashlc_get_exchange_rate_usd(runtime)

        if rate.is_sign_negative {
            throw ZcashError.rustTorClientGet(lastErrorMessage(fallback: "`TorClient.get` failed with unknown error"))
        }

        return NSDecimalNumber(mantissa: rate.mantissa, exponent: rate.exponent, isNegative: rate.is_sign_negative)
    }
}
