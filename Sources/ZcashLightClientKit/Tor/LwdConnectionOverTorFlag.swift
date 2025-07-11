//
//  LwdConnectionOverTorFlag.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-07-11.
//

/// A singleton that controls  `SeviceMode` for the connection to the `LightWalletService`.
/// When disabled, the `ServiceMode.direct` (GRPC) is enforeced.
/// When enabled, all Tor cases in `ServiceMode` are allowed.
public actor LwdConnectionOverTorFlag {
    static public let shared = LwdConnectionOverTorFlag()

    private init() { }

    /// Accessible only internaly inside the SDK to control the connection
    var enabled = false

    /// Use to update the flag of `LwdConnectionOverTorFlag`
    public func update(_ newState: Bool) {
        enabled = newState
    }
}
