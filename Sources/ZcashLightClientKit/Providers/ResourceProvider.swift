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
    var network: ZcashNetwork

    public var dataDbURL: URL {
        let constants = network.constants
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return url.appendingPathComponent(constants.defaultDataDbName)
        } catch {
            return URL(fileURLWithPath: "file://\(constants.defaultDataDbName)")
        }
    }
    
    public var cacheDbURL: URL {
        let constants = network.constants
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return path.appendingPathComponent(constants.defaultCacheDbName)
        } catch {
            return URL(fileURLWithPath: "file://\(constants.defaultCacheDbName)")
        }
    }

    public var spendParamsURL: URL {
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return path.appendingPathComponent(ZcashSDK.spendParamFilename)
        } catch {
            return URL(fileURLWithPath: "file://\(ZcashSDK.spendParamFilename)")
        }
    }

    public var outputParamsURL: URL {
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return path.appendingPathComponent(ZcashSDK.outputParamFilename)
        } catch {
            return URL(fileURLWithPath: "file://\(ZcashSDK.outputParamFilename)")
        }
    }
    
    init(network: ZcashNetwork) {
        self.network = network
    }
}
