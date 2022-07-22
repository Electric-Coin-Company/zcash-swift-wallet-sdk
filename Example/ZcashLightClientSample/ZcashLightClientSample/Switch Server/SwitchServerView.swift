//
//  SwitchServerView.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 7/21/22.
//  Copyright © 2022 Electric Coin Company. All rights reserved.
//

import SwiftUI

class SwitchServerModel: ObservableObject {
    var serverAndPort: String
    var serverInfo: String

    init(serverAndPort: String = "testnet.lightwalletd.com:9067", serverInfo: String = "" ) {
        self.serverAndPort = serverAndPort
        self.serverInfo = serverInfo
    }
}

struct SwitchServerView: View {
    @StateObject var model: SwitchServerModel
    var connectionSwitcher: () -> Void
    var currentServer: () -> String
    var body: some View {
        VStack(alignment: .center, spacing: 30){
            Text("Current Server: \(currentServer())")
            TextField("LightWalletdServer", text: $model.serverAndPort)
            Button("Switch to server") {
                connectionSwitcher()
            }
            Text(model.serverInfo)
                .multilineTextAlignment(.leading)
        }
        .padding()
    }
}

struct SwitchServerView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchServerView(
            model: SwitchServerModel(),
            connectionSwitcher: ConnectionSwitcher.demo,
            currentServer: CurrentServerFetcher.demo
        )
    }
}

enum CurrentServerFetcher {
    static let demo = {
        "testnet.free2z.org:9067"
    }
}

enum ConnectionSwitcher {
    static let demo = {}
}
