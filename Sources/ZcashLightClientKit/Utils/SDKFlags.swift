//
//  SDKFlags.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-07-18.
//

/// A singleton actor with control flags for the SDK.
actor SDKFlags {
    /// `torEnabled` controls `SeviceMode` for the connection to the `LightWalletService`.
    /// When disabled, the `ServiceMode.direct` (GRPC) is enforced.
    /// When enabled, all Tor cases in `ServiceMode` are allowed.
    /// Accessible only internally inside the SDK to control the connection
    var torEnabled: Bool
    
    /// This flag communicates state of initialization of `TorClient`
    /// `nil` = the attempt to initialize `TorClient` hasn't been initiated
    /// `false` = initialization of `TorClient` failed
    /// `true` = initialization of `TorClient` succeeded
    var torClientInitializationSuccessfullyDone: Bool?
    
    init(
        torEnabled: Bool
    ) {
        self.torEnabled = torEnabled
    }
    
    /// Helper method that wraps the decision logic for `ServiceMode`.
    /// When Tor is not enabled, it always must use fallback to `.direct` mode.
    func ifTor(_ serviceMode: ServiceMode) -> ServiceMode {
        torEnabled ? serviceMode : .direct
    }
    
    /// Use to update the `torEnabled` flag
    func torFlagUpdate(_ newFlag: Bool) {
        torEnabled = newFlag
    }
    
    /// Use to update the `torClientInitializationSuccessfullyDone` flag
    func torClientInitializationSuccessfullyDoneFlagUpdate(_ newFlag: Bool?) {
        torClientInitializationSuccessfullyDone = newFlag
    }
}
