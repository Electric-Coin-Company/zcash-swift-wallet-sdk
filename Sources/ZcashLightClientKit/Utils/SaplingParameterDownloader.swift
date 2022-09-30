//
//  SaplingParameterDownloader.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/7/20.
//

import Foundation
/**
Helper class to handle the download of Sapling parameters
*/
public enum SaplingParameterDownloader {
    public enum Errors: Error {
        case invalidURL(url: String)
        case failed(error: Error)
    }
    
    /// Download a Spend parameter from default host and stores it at given URL
    /// - Parameters:
    ///     - at: The destination URL for the download
    @discardableResult
    public static func downloadSpendParameter(_ at: URL) async throws -> URL {
        guard let url = URL(string: spendParamsURLString) else {
            throw Errors.invalidURL(url: spendParamsURLString)
        }

        return try await withCheckedThrowingContinuation { continuation in
            downloadFileWithRequest(URLRequest(url: url), at: at) { result in
                switch result {
                case .success(let outputResultURL):
                    continuation.resume(returning: outputResultURL)
                case .failure(let outputResultError):
                    continuation.resume(throwing: outputResultError)
                }
            }
        }
    }
    
    /// Download an Output parameter from default host and stores it at given URL
    /// - Parameters:
    ///     - at: The destination URL for the download
    @discardableResult
    public static func downloadOutputParameter(_ at: URL) async throws -> URL {
        guard let url = URL(string: outputParamsURLString) else {
            throw Errors.invalidURL(url: outputParamsURLString)
        }

        return try await withCheckedThrowingContinuation { continuation in
            downloadFileWithRequest(URLRequest(url: url), at: at) { result in
                switch result {
                case .success(let outputResultURL):
                    continuation.resume(returning: outputResultURL)
                case .failure(let outputResultError):
                    continuation.resume(throwing: outputResultError)
                }
            }
        }
    }
    
    private static func downloadFileWithRequest(_ request: URLRequest, at destination: URL, result: @escaping (Result<URL, Error>) -> Void) {
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
    
    /// Downloads the parameters if not present and provides the resulting URLs for both parameters
    /// - Parameters:
    ///     - spendURL: URL to check whether the parameter is already downloaded
    ///     - outputURL: URL to check whether the parameter is already downloaded
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
            return url
        } else {
            return try await downloadSpendParameter(url)
        }
    }
    
    static func ensureOutputParameter(at url: URL) async throws -> URL {
        if isFilePresent(url: url) {
            return url
        } else {
            return try await downloadOutputParameter(url)
        }
    }
    
    static func isFilePresent(url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
    
    public static var spendParamsURLString: String {
        return ZcashSDK.cloudParameterURL + ZcashSDK.spendParamFilename
    }
    
    public static var outputParamsURLString: String {
        return ZcashSDK.cloudParameterURL + ZcashSDK.outputParamFilename
    }
}
