//
//  SwitchServerView.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 7/21/22.
//  Copyright © 2022 Electric Coin Company. All rights reserved.
//

import SwiftUI

class SwitchServerModel: ObservableObject {
    @Published var serverAndPort: String
    @Published var serverInfo: String
    var connectionSwitcher: () -> Void
    var currentServer: () -> String

    var sameServer: Bool {
        currentServer() == serverAndPort
    }

    init(
        serverAndPort: String = "testnet.lightwalletd.com:9067",
        serverInfo: String = "",
        connectionSwitcher: @escaping () -> Void = ConnectionSwitcher.demo,
        currentServer: @escaping () -> String = CurrentServerFetcher.demo
    ) {
        self.serverAndPort = serverAndPort
        self.serverInfo = serverInfo
        self.connectionSwitcher = connectionSwitcher
        self.currentServer = currentServer
    }
}

struct SwitchServerView: View {
    @StateObject var model: SwitchServerModel

    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            Text("Current Server: \(model.currentServer())")
            TextField("LightWalletdServer", text: $model.serverAndPort)
                .textCase(.none)
                .textInputAutocapitalization(.never)
                .textContentType(.URL)

            Button("Switch to server") {
                model.connectionSwitcher()
            }
            .disabled(model.sameServer)

            Text(model.serverInfo)
                .multilineTextAlignment(.leading)
        }
        .padding()
    }
}

struct SwitchServerView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchServerView(
            model: SwitchServerModel()
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
