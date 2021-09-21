//
//  SampleStorage.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/20/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

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
    // swiftlint:disable:next implicitly_unwrapped_optional
    static var shared: WalletStorage! {
        _shared
    }
    
    private static var _shared = SampleStorage()

    private let keySeed = "cash.z.wallet.sdk.demoapp.SEED"
    private let keyPK = "cash.z.wallet.sdk.demoapp.PK"

    var seed: Data? {
        get {
            // swiftlint:disable:next force_cast
            UserDefaults.standard.value(forKey: keySeed) as! Data?
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keySeed)
        }
    }
    
    var privateKey: String? {
        get {
            // swiftlint:disable:next force_cast
            UserDefaults.standard.value(forKey: keyPK) as! String?
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keyPK)
        }
    }

    private init() {}
}
