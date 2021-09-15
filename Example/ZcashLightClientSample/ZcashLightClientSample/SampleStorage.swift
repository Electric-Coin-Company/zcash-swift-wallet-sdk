//
//  SampleStorage.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/20/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
// swiftlint:disable line_length force_try
import Foundation

protocol WalletStorage {
    var seed: Data? { get set }
    var privateKey: String? { get set }
}

/**
 DO NOT STORE YOUR KEYS ON USER DEFAULTS!!!
 USE KEYCHAIN OR ANY OTHER SECURE STORAGE MECHANISM OF YOUR CHOICE
 USE AT YOUR OWN RISK
 */
class SampleStorage: WalletStorage {
    private init() {}
    private static var _shared = SampleStorage()
    static var shared: WalletStorage! {
        _shared
    }
    private let keySeed = "cash.z.wallet.sdk.demoapp.SEED"
    private let keyPK = "cash.z.wallet.sdk.demoapp.PK"
    var seed: Data? {
        set {
            UserDefaults.standard.set(newValue, forKey: keySeed)
        }
        get {
            UserDefaults.standard.value(forKey: keySeed) as! Data?
        }
    }
    
    var privateKey: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: keyPK)
        }
        get {
            UserDefaults.standard.value(forKey: keyPK) as! String?
        }
    }
}
