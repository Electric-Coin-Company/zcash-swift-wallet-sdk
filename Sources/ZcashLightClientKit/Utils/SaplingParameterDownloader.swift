//
//  SaplingParameterDownloader.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/7/20.
//

import Foundation
import CryptoKit

/// Small utility that converts Digest to the String
extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// Helper class to handle the download of Sapling parameters
public enum SaplingParameterDownloader {
    public enum Errors: Error {
        case invalidURL(url: String)
        case failed(error: Error)
        case spendParamsInvalidSHA1
        case outputParamsInvalidSHA1
    }
    
    public static var spendParamsURLString: String {
        return ZcashSDK.cloudParameterURL + ZcashSDK.spendParamFilename
    }
    
    public static var outputParamsURLString: String {
        return ZcashSDK.cloudParameterURL + ZcashSDK.outputParamFilename
    }

    /// Download a Spend parameter from default host and stores it at given URL
    /// - Parameters:
    ///     - at: The destination URL for the download
    @discardableResult
    public static func downloadSpendParameter(_ at: URL) async throws -> URL {
        guard let url = URL(string: spendParamsURLString) else {
            throw Errors.invalidURL(url: spendParamsURLString)
        }

        let resultURL = try await downloadFileWithRequestWithContinuation(URLRequest(url: url), at: at)
        try isSpendParamsSHA1Valid(url: resultURL)
        return resultURL
    }
    
    /// Download an Output parameter from default host and stores it at given URL
    /// - Parameters:
    ///     - at: The destination URL for the download
    @discardableResult
    public static func downloadOutputParameter(_ at: URL) async throws -> URL {
        guard let url = URL(string: outputParamsURLString) else {
            throw Errors.invalidURL(url: outputParamsURLString)
        }

        let resultURL = try await downloadFileWithRequestWithContinuation(URLRequest(url: url), at: at)
        try isOutputParamsSHA1Valid(url: resultURL)
        return resultURL
    }

    /// Downloads the parameters if not present and provides the resulting URLs for both parameters
    /// - Parameters:
    ///     - spendURL: URL to check whether the parameter is already downloaded
    ///     - outputURL: URL to check whether the parameter is already downloaded
    @discardableResult
    public static func downloadParamsIfnotPresent(
        spendURL: URL,
        outputURL: URL
    ) async throws -> (spend: URL, output: URL) {
        do {
            async let spendResultURL = ensureSpendParameter(at: spendURL)
            async let outputResultURL = ensureOutputParameter(at: outputURL)
            
            let results = try await [spendResultURL, outputResultURL]
            return (spend: results[0], output: results[1])
        } catch {
            throw Errors.failed(error: error)
        }
    }
        
    static func ensureSpendParameter(at url: URL) async throws -> URL {
        if isFilePresent(url: url) {
            try isSpendParamsSHA1Valid(url: url)
            return url
        } else {
            return try await downloadSpendParameter(url)
        }
    }
    
    static func ensureOutputParameter(at url: URL) async throws -> URL {
        if isFilePresent(url: url) {
            try isOutputParamsSHA1Valid(url: url)
            return url
        } else {
            return try await downloadOutputParameter(url)
        }
    }
    
    static func isFilePresent(url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
    
    static func isSpendParamsSHA1Valid(url: URL) throws {
        if Insecure.SHA1.hash(data: try Data(contentsOf: url)).hexString != Constants.spendParamFileSHA1 {
            try FileManager.default.removeItem(at: url)
            throw Errors.spendParamsInvalidSHA1
        }
    }

    static func isOutputParamsSHA1Valid(url: URL) throws {
        if Insecure.SHA1.hash(data: try Data(contentsOf: url)).hexString != Constants.outputParamFileSHA1 {
            try FileManager.default.removeItem(at: url)
            throw Errors.outputParamsInvalidSHA1
        }
    }
}

private extension SaplingParameterDownloader {
    enum Constants {
        public static let spendParamFileSHA1 = "a15ab54c2888880e53c823a3063820c728444126"
        public static let outputParamFileSHA1 = "0ebc5a1ef3653948e1c46cf7a16071eac4b7e352"
    }

    static func downloadFileWithRequestWithContinuation(
    _ request: URLRequest,
    at destination: URL
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            downloadFileWithRequest(request, at: destination) { result in
                switch result {
                case .success(let outputResultURL):
                    continuation.resume(returning: outputResultURL)
                case .failure(let outputResultError):
                    continuation.resume(throwing: outputResultError)
                }
            }
        }
    }

    static func downloadFileWithRequest(
        _ request: URLRequest,
        at destination: URL,
        result: @escaping (Result<URL, Error>) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: request) { url, _, error in
            if let error = error {
                result(.failure(Errors.failed(error: error)))
                return
            } else if let localUrl = url {
                do {
                    try FileManager.default.moveItem(at: localUrl, to: destination)
                    result(.success(destination))
                } catch {
                    result(.failure(error))
                }
            }
        }

        task.resume()
    }
}
