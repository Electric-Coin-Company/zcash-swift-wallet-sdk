//
//  Tests+Utils.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import ZcashLightClientKit
import XCTest
import NIO
class LightWalletEndpointBuilder {
    static var `default`: LightWalletEndpoint {
        LightWalletEndpoint(address: Constants.address, port: 9067, secure: false)
    }
}

class ChannelProvider {
    func channel(secure: Bool = false) -> GRPCChannel {
        let endpoint = LightWalletEndpointBuilder.default
        
        let configuration = ClientConnection.Configuration(target: .hostAndPort(endpoint.host, endpoint.port), eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1), tls: secure ? .init() : nil)
        return ClientConnection(configuration: configuration)
       
    }
}

struct MockDbInit {
    @discardableResult static func emptyFile(at path: String) -> Bool {
        
        FileManager.default.createFile(atPath: path, contents: Data("".utf8), attributes: nil)
        
    }
    
    static func destroy(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

}

extension XCTestExpectation {
    func subscribe(to notification: Notification.Name, object: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(fulfill), name: notification, object: object)
    }
    
    func unsubscribe(from notification: Notification.Name) {
        NotificationCenter.default.removeObserver(self, name: notification, object: nil)
    }
    
    func unsubscribeFromNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

func __documentsDirectory() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
}

func __cacheDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("cache.db", isDirectory: false)
}

func __dataDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("data.db", isDirectory: false)
}

func __spendParamsURL() throws -> URL {
    URL(string: Bundle.testBundle.url(forResource: "sapling-spend", withExtension: "params")!.path)!
}

func __outputParamsURL() throws -> URL {
    URL(string: Bundle.testBundle.url(forResource: "sapling-output", withExtension: "params")!.path)!
}

func copyParametersToDocuments() throws -> (spend: URL, output: URL) {
    
    let spendURL = try __documentsDirectory().appendingPathComponent("sapling-spend.params", isDirectory: false)
    let outputURL = try __documentsDirectory().appendingPathComponent("sapling-output.params", isDirectory: false)
    try FileManager.default.copyItem(at: try __spendParamsURL(), to: spendURL)
    try FileManager.default.copyItem(at: try __outputParamsURL(), to: outputURL)
    
    return (spendURL, outputURL)
}

func deleteParametersFromDocuments() throws {
    let documents = try __documentsDirectory()
    deleteParamsFrom(spend: documents.appendingPathComponent("sapling-spend.params"), output: documents.appendingPathComponent("sapling-output.params"))
}
func deleteParamsFrom(spend: URL, output: URL)  {
    try? FileManager.default.removeItem(at: spend)
    try? FileManager.default.removeItem(at: output)
}

func parametersReady() -> Bool {
    
    guard let output = try? __outputParamsURL(),
          let spend = try? __spendParamsURL(),
          FileManager.default.isReadableFile(atPath: output.absoluteString),
          FileManager.default.isReadableFile(atPath: spend.absoluteString) else {
            return false
    }
    return true
}

class StubTest: XCTestCase {}
extension Bundle {
    static var testBundle: Bundle {
        Bundle(for: StubTest.self)
    }
}


class TestSeed: SeedProvider {
    
    /**
     test account: "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"
     */
    let seedString = "f550d5399659396587a59b6ad446eb89da7741ebb1e42f87c22451d20ece8bb1e09ccb3c19f967f37fbf435367bc295c692c0ce000c52f5b991f1ca91169565e"
    
    func seed() -> [UInt8] {
        [UInt8](seedString.hexDecodedData())
    }
}
