//
//  ResourceProvider.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 19/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public enum ResourceProviderError: Error {
    case unavailableResource
}
public protocol ResourceProvider {
    
    var dataDbURL: URL { get }
    var cacheDbURL: URL { get }
    
}
/**
 Convenience provider for a data db and cache db resources. 
 */
public struct DefaultResourceProvider: ResourceProvider {
     
     public var dataDbURL: URL {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return url.appendingPathComponent(ZcashSDK.DEFAULT_DATA_DB_NAME)
        } catch {
            return URL(fileURLWithPath: "file://\(ZcashSDK.DEFAULT_DATA_DB_NAME)")
        }
        
    }
    
    public var cacheDbURL: URL {
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return path.appendingPathComponent(ZcashSDK.DEFAULT_CACHES_DB_NAME)
        } catch {
            return URL(fileURLWithPath: "file://\(ZcashSDK.DEFAULT_CACHES_DB_NAME)")
        }
    }
    
}
