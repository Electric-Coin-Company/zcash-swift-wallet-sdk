//
//  SDKFlags.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-07-18.
//

/// The Tor setup in the SDK depends on which feature is expected to run over Tor.
/// Not everytime all features are over Tor and this enum allows to have a granular control over Tor setup.
public enum SDKFlagTorMode {
    /// Tor is turned off
    case none
    /// Tor is on but for fetching exchange rate only
    case exchangeRate
    /// Tor is on for all features (exchange rate and lwd service)
    case all
}

/// A singleton actor with control flags for the SDK.
actor SDKFlags {
    /// `torEnabled` controls `SeviceMode` for the connection to the `LightWalletService`.
    /// When disabled, the `ServiceMode.direct` (GRPC) is enforced.
    /// When enabled, all Tor cases in `ServiceMode` are allowed.
    /// Accessible only internally inside the SDK to control the connection
    var torEnabled: Bool

    /// `exchangeRateEnabled` controls whether fetch of exnchage rate is enabled or disabled.
    /// When enabled, the `TorClient` is initialized but is not used for lwdService calls.
    var exchangeRateEnabled: Bool
    
    /// This flag communicates state of initialization of `TorClient`
    /// `nil` = the attempt to initialize `TorClient` hasn't been initiated
    /// `false` = initialization of `TorClient` failed
    /// `true` = initialization of `TorClient` succeeded
    var torClientInitializationSuccessfullyDone: Bool?
    
    init(
        torEnabled: Bool,
        exchangeRateEnabled: Bool
    ) {
        self.torEnabled = torEnabled
        self.exchangeRateEnabled = exchangeRateEnabled
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

    /// Use to update the `exchangeRateEnabled` flag
    func exchangeRateFlagUpdate(_ newFlag: Bool) {
        exchangeRateEnabled = newFlag
    }

    /// Use to update the `torClientInitializationSuccessfullyDone` flag
    func torClientInitializationSuccessfullyDoneFlagUpdate(_ newFlag: Bool?) {
        torClientInitializationSuccessfullyDone = newFlag
    }
}
