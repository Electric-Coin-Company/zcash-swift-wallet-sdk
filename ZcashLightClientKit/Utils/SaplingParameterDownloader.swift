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
public class SaplingParameterDownloader {
    public enum Errors: Error {
        case invalidURL(url: String)
        case failed(error: Error)
    }
    
    /**
     Download a Spend parameter from default host and stores it at given URL
     - Parameters:
      - at: The destination URL for the download
      - result: block to handle the download success or error
     */
    public static func downloadSpendParameter(_ at: URL, result: @escaping (Result<URL, Error>) -> Void) {
        
        guard let url = URL(string: spendParamsURLString) else {
            result(.failure(Errors.invalidURL(url: spendParamsURLString)))
            return
        }
       downloadFileWithRequest(URLRequest(url: url), at: at, result: result)
    }
    /**
     Download an Output parameter from default host and stores it at given URL
     - Parameters:
      - at: The destination URL for the download
      - result: block to handle the download success or error
     */
    public static func downloadOutputParameter(_ at: URL, result: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: outputParamsURLString) else {
            result(.failure(Errors.invalidURL(url: outputParamsURLString)))
            return
        }
        downloadFileWithRequest(URLRequest(url: url), at: at, result: result)
    }
    
    private static func downloadFileWithRequest(_ request: URLRequest, at destination: URL, result: @escaping (Result<URL,Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: request) { (url, _, error) in
             if let e = error {
                 result(.failure(Errors.failed(error: e)))
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
    /**
     Downloads the parameters if not present and provides the resulting URLs for both parameters
     - Parameters:
       - spendURL: URL to check whether the parameter is already downloaded
       - outputURL: URL to check whether the parameter is already downloaded
       - result: block to handle success or error
     */
    public static func downloadParamsIfnotPresent(spendURL: URL, outputURL: URL, result: @escaping (Result<(spend: URL, output: URL),Error>) -> Void) {
        
        ensureSpendParameter(at: spendURL) { (spendResult) in
            switch spendResult {
            case .success(let spendResultURL):
                ensureOutputParameter(at: outputURL) { (outputResult) in
                    switch outputResult {
                    case .success(let outputResultURL):
                        result(.success((spendResultURL,outputResultURL)))
                    case .failure(let outputResultError):
                        result(.failure(Errors.failed(error: outputResultError)))
                    }
                }
            case .failure(let spendResultError):
                result(.failure(Errors.failed(error: spendResultError)))
            }
        }
    }
    
    static func ensureSpendParameter(at url: URL, result: @escaping (Result<URL,Error>) -> Void) {
        if isFilePresent(url: url) {
            DispatchQueue.global().async {
                result(.success(url))
            }
        } else {
            downloadSpendParameter(url, result: result)
        }
    }
    
    static func ensureOutputParameter(at url: URL, result: @escaping (Result<URL,Error>) -> Void) {
        if isFilePresent(url: url) {
            DispatchQueue.global().async {
                result(.success(url))
            }
        } else {
            downloadOutputParameter(url, result: result)
        }
    }
    
    static func isFilePresent(url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
    
    public static var spendParamsURLString: String {
        return ZcashSDK.CLOUD_PARAM_DIR_URL + ZcashSDK.SPEND_PARAM_FILE_NAME
    }
    
    public static var outputParamsURLString: String {
        return ZcashSDK.CLOUD_PARAM_DIR_URL + ZcashSDK.OUTPUT_PARAM_FILE_NAME
    }
}
