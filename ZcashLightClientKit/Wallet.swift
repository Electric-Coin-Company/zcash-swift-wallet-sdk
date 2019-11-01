//
//  Wallet.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
/**
 Wrapper for the Rust backend. This class basically represents all the Rust-wallet
 capabilities and the supporting data required to exercise those abilities.
 */

public enum WalletError: Error {
    case cacheDbInitFailed
    case dataDbInitFailed
    case accountInitFailed
    case falseStart
}

public class Wallet {
    
    private var rustBackend: ZcashRustBackendWelding.Type = ZcashRustBackend.self
    private var lowerBoundHeight: BlockHeight = SAPLING_ACTIVATION_HEIGHT
    private var cacheDbURL: URL
    private var dataDbURL: URL
    
    public init (cacheDbURL: URL, dataDbURL: URL) {
        self.cacheDbURL = cacheDbURL
        self.dataDbURL = dataDbURL
    }
    
    public func initialize(seedProvider: SeedProvider, walletBirthdayHeight: BlockHeight, numberOfAccounts: Int = 1) throws -> [String]? {
        
        do {
            try rustBackend.initDataDb(dbData: dataDbURL)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw WalletError.dataDbInitFailed
        }

        guard let birthday = WalletBirthday.birthday(with: walletBirthdayHeight) else {
            throw WalletError.falseStart
        }
        
        lowerBoundHeight = birthday.height
        
        do {
            try rustBackend.initBlocksTable(dbData: dataDbURL, height: Int32(birthday.height), hash: birthday.hash, time: birthday.time, saplingTree: birthday.tree)
        } catch RustWeldingError.dataDbNotEmpty {
            // this is fine
        } catch {
            throw WalletError.dataDbInitFailed
        }
        
        guard let accounts = rustBackend.initAccountsTable(dbData: dataDbURL, seed: seedProvider.seed(), accounts: Int32(numberOfAccounts)) else {
            throw rustBackend.lastError() ?? WalletError.accountInitFailed
        }
        
        return accounts
    }
    
    public func getAddress(index account: Int = 0) -> String? {
        return rustBackend.getAddress(dbData: dataDbURL, account: Int32(account))
    }
    
}

/**
 Represents the wallet's birthday which can be thought of as a checkpoint at the earliest moment in history where
 transactions related to this wallet could exist. Ideally, this would correspond to the latest block height at the
 time the wallet key was created. Worst case, the height of Sapling activation could be used (280000).
 
 Knowing a wallet's birthday can significantly reduce the amount of data that it needs to download because none of
 the data before that height needs to be scanned for transactions. However, we do need the Sapling tree data in
 order to construct valid transactions from that point forward. This birthday contains that tree data, allowing us
 to avoid downloading all the compact blocks required in order to generate it.
 
 New wallets can ignore any blocks created before their birthday.
 
 - Parameter height the height at the time the wallet was born
 - Parameter hash the block hash corresponding to the given height
 - Parameter time the time the wallet was born, in seconds
 - Parameter tree the sapling tree corresponding to the given height. This takes around 15 minutes of processing to
 generate from scratch because all blocks since activation need to be considered. So when it is calculated in
 advance it can save the user a lot of time.
 */
public struct WalletBirthday {
    var height: BlockHeight = -1
    var hash: String = ""
    var time: UInt32 = 0
    var tree: String = ""
}

// TODO: remove this in favor of loading these from disk
public extension WalletBirthday {
    static func birthday(with height: BlockHeight) -> WalletBirthday? {
        switch height {
        case 280_000:
            return WalletBirthday(height: 280000, hash: "000420e7fcc3a49d729479fb0b560dd7b8617b178a08e9e389620a9d1dd6361a", time: 1535262293, tree: "000000")
        case 421720:
            return WalletBirthday(height: 421720, hash: "001ede53476a31a91da3313eddf4e41409fb7f4e003840700557b576024d09b4", time: 1550762014, tree: "015495a30aef9e18b9c774df6a9fcd583748c8bba1a6348e70f59bc9f0c2bc673b000f00000000018054b75173b577dc36f2c80dfc41f83d6716557597f74ec54436df32d4466d57000120f1825067a52ca973b07431199d5866a0d46ef231d08aa2f544665936d5b4520168d782e3d028131f59e9296c75de5a101898c5e53108e45baa223c608d6c3d3d01fb0a8d465b57c15d793c742df9470b116ddf06bd30d42123fdb7becef1fd63640001a86b141bdb55fd5f5b2e880ea4e07caf2bbf1ac7b52a9f504977913068a917270001dd960b6c11b157d1626f0768ec099af9385aea3f31c91111a8c5b899ffb99e6b0192acd61b1853311b0bf166057ca433e231c93ab5988844a09a91c113ebc58e18019fbfd76ad6d98cafa0174391546e7022afe62e870e20e16d57c4c419a5c2bb69")
        case 425865:
            return WalletBirthday(height: 425865, hash: "0011c4de26004e564347b8af218ca16cd07b08c4159b1cc9c43afa6cb8807bed", time: 1551215770, tree: "01881e4da7e4767ee8a144a32ab8a5719a513bb05854477773bb55e6cd7f15055201f8a99a3a5ae3528ec2fc0bda9652b6728aecb08bf364e06ac511fd6654d782720f019ef0b9bdd075c38519fa4ab8210fe7e94c609f52672796e33e3cab58b1602831000001f803bf338ff1526b2ca527288974cb9be3fe240a2eadb7507e46ba59eaddb9320129fc0148ac088a6aa509f8f64ef79fda92232020369b58a12b32c05b6f428f22015e3dd0950c442940bd015c2176f7c817f22104f54c61159727483188c539dc13000000013589be9e2d9e9e38fd78b1e8eaec5b5f5167bf7fd2b1c95c316fa366a24cac4c01a86b141bdb55fd5f5b2e880ea4e07caf2bbf1ac7b52a9f504977913068a917270001dd960b6c11b157d1626f0768ec099af9385aea3f31c91111a8c5b899ffb99e6b0192acd61b1853311b0bf166057ca433e231c93ab5988844a09a91c113ebc58e18019fbfd76ad6d98cafa0174391546e7022afe62e870e20e16d57c4c419a5c2bb69")
        case 518000:
            return WalletBirthday(height: 518000, hash: "000ba586d734c295f0bc034be229b1c96cb040f9d4929efdb5d2b187eeb238fb", time: 1560645743, tree: "01a4f5240a88a6eb4ffbda7961a1430506aad1a50ba011593f02c243d968feb0550010000140f91773b4ab669846e5bcb96f60e68256c49a27872a98e9d5ce50b30a0c434e0000018968663d6a7b444591de83f8a07223113f5de7e8203807adacc7677c3bcd4f420194c7ecac0ef6d702d475680ec32051fdf6368af0c459ab450009c001bcbf7a5300000001f0eead5192c3b3ab7208429877570676647e448210332c6da7e18660b142b80e01b98b14cab05247195b3b3be3dd8639bae99a0dd10bed1282ac25b62a134afd7200000000011f8322ef806eb2430dc4a7a41c1b344bea5be946efc7b4349c1c9edb14ff9d39")
        case 523240:
            return WalletBirthday(height: 523240, hash: "00000c33da2196f0ed1bda71043f671fc69a0212e01f892653e212ab358f6b79", time: 1561002603, tree: "01d3e02bc1c2d66762f370b329a3063067701ad66c44b40285686bc8ff25f5616f00100154bff87bd0bda3b70a6d7754eca261de15fee3cd9bc53073a232e07fc3261e27000001a54dcaccb4c5e578aef89f2a3b4e3c3d8a487e6e904c5da5916118d721948d07000000000118fa9c6fef4963049dc7002a13bb0021d5e950591e48c9e5f2cbd1199429b80401f0eead5192c3b3ab7208429877570676647e448210332c6da7e18660b142b80e01b98b14cab05247195b3b3be3dd8639bae99a0dd10bed1282ac25b62a134afd7200000000011f8322ef806eb2430dc4a7a41c1b344bea5be946efc7b4349c1c9edb14ff9d39")
        case 620000:
            return WalletBirthday(height: 620000, hash: "005f97953c8e1265d6b45f4435ffa32918e53e8f0025c286a4080c3eab167197", time: 1569572035, tree: "0170cf036ea1ea3c6e08432e18b6a372ca0b8b83671cc13ab0cf9e28c182f6c36f00100000013f3fc2c16ac4780f1c472ca65534ab08911f325a9edde5ea7f24364b47c9a95300017621b12e518cbbbdb7511ab423e0bddda412ed61ed3cff5be2140de65d6a0069010576153a5a2098812e7a028c37c3398e186f398c9b07bc199784ab97e5535c3e0000019a6ce2f0f7dbb2de493a315abf62d8ca96ccc701f116b6ddfae33870a2183d3c01c9d3564eff54ebc328eab2e4f1150c3637f4f47516f879a0cfebdf49fe7b1d5201c104705fac60a85596010e41260d07f3a64f38f37a112eaef41cd9d736edc5270145e3d4899fcd7f0f1236ae31eafb3f4b65ad6b11a17eae1729cec09bd3afa01a000000011f8322ef806eb2430dc4a7a41c1b344bea5be946efc7b4349c1c9edb14ff9d39")
        default:
            return nil
        }
    }
}
