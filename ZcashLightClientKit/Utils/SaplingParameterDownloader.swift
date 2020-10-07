//
//  SaplingParameterDownloader.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/7/20.
//

import Foundation

public class SaplingParameterDownloader {
    public enum Errors: Error {
        case invalidURL(url: String)
        case failed(error: Error)
    }
    
    public static func downloadSpendParameter(_ at: URL, result: @escaping (Result<URL, Error>) -> Void) {
        
        guard let url = URL(string: spendParamsURLString) else {
            result(.failure(Errors.invalidURL(url: spendParamsURLString)))
            return
        }
       downloadFileWithRequest(URLRequest(url: url), at: at, result: result)
    }
    
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
    
    static var spendParamsURLString: String {
        return ZcashSDK.CLOUD_PARAM_DIR_URL + ZcashSDK.SPEND_PARAM_FILE_NAME
    }
    
    static var outputParamsURLString: String {
        return ZcashSDK.CLOUD_PARAM_DIR_URL + ZcashSDK.OUTPUT_PARAM_FILE_NAME
    }
}
