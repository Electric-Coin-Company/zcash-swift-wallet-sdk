//
//  Tests+Utils.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Combine
import Foundation
import GRPC
import ZcashLightClientKit
import XCTest
import NIO
import NIOTransportServices

enum Environment {
    static let lightwalletdKey = "LIGHTWALLETD_ADDRESS"
    static let seedPhrase = """
    still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge \
    solid fish spread
    """

    // Seed bytes for `seedPhrase`.
    static var seedBytes: [UInt8] {
        let seedString = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!
        return [UInt8](seedString)
    }

    static let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"
}

public enum Constants {
    static let address: String = ProcessInfo.processInfo.environment[Environment.lightwalletdKey] ?? "localhost"
}

enum LightWalletEndpointBuilder {
    static var `default`: LightWalletEndpoint {
        LightWalletEndpoint(address: Constants.address, port: 9067, secure: false)
    }
    
    static var publicTestnet: LightWalletEndpoint {
        LightWalletEndpoint(address: "testnet.lightwalletd.com", port: 9067, secure: true)
    }
    
    static var eccTestnet: LightWalletEndpoint {
        LightWalletEndpoint(address: "lightwalletd.testnet.electriccoin.co", port: 9067, secure: true)
    }
}

class ChannelProvider {
    func channel(secure: Bool = false) -> GRPCChannel {
        let endpoint = LightWalletEndpointBuilder.default

        let connectionBuilder = secure ?
        ClientConnection.usingPlatformAppropriateTLS(for: NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default)) :
        ClientConnection.insecure(group: NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default))

        let channel = connectionBuilder
            .withKeepalive(
                ClientConnectionKeepalive(
                    interval: .seconds(15),
                    timeout: .seconds(10)
                )
            )
            .connect(host: endpoint.host, port: endpoint.port)

        return channel
    }
}

enum MockDbInit {
    @discardableResult
    static func emptyFile(at path: String) -> Bool {
        FileManager.default.createFile(atPath: path, contents: Data("".utf8), attributes: nil)
    }
    
    static func destroy(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
}

func __documentsDirectory() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
}

func __dataDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("data.db", isDirectory: false)
}

func __spendParamsURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("sapling-spend.params")
}

func __outputParamsURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("sapling-output.params")
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
    deleteParamsFrom(
        spend: documents.appendingPathComponent("sapling-spend.params"),
        output: documents.appendingPathComponent("sapling-output.params")
    )
}

func deleteParamsFrom(spend: URL, output: URL) {
    try? FileManager.default.removeItem(at: spend)
    try? FileManager.default.removeItem(at: output)
}

func parametersReady() -> Bool {
    guard
        let output = try? __outputParamsURL(),
        let spend = try? __spendParamsURL(),
        FileManager.default.isReadableFile(atPath: output.absoluteString),
        FileManager.default.isReadableFile(atPath: spend.absoluteString)
    else {
        return false
    }

    return true
}
