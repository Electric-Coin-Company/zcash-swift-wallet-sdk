//
//  DerivationToolTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 10/9/20.
//
//swiftlint:disable force_unwrapping
import XCTest
import ZcashLightClientKit

class DerivationToolMainnetTests: XCTestCase {
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" //TODO: Parameterize this from environment?
    var seedData: Data = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!
    let testRecipientAddress = "zs1vp7kvlqr4n9gpehztr76lcn6skkss9p8keqs3nv8avkdtjrcctrvmk9a7u494kluv756jeee5k0" //TODO: Parameterize this from environment
    
    let expectedSpendingKey = "secret-extended-key-main1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkyuegyhh5d4rdr8025nl7e0hm8r2txx3fuea5mquy3wnsr9tlajsg4wwvw0xcfk8357k4h850rgj72kt4rx3fjdz99zs9f4neda35cq8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszc7nc9vv"
    
    let expectedViewingKey = "zxviews1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkysswfhjk79n8l99f2grd26dqg6dy3jcmxsaypxfsu6ara6vsk3x8l544uaksstx9zre879mdg7s9a7zurrx6pf5qg2n323js2s3zlu8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszcq7kwxy"
    
    let derivationTool = DerivationTool(networkType: NetworkType.mainnet)
    let expectedTransparentAddress = "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz"
    func testDeriveViewingKeysFromSeed() throws {
        let accounts: Int = 1
        let seedBytes = [UInt8](seedData)
        let viewingKeys = try derivationTool.deriveViewingKeys(seed: seedBytes, numberOfAccounts: accounts)

        XCTAssertEqual(viewingKeys.count, accounts, "the number of viewing keys have to match the number of account requested to derive")

        guard let viewingKey = viewingKeys.first else {
            XCTFail("no viewing key generated")
            return
        }
        XCTAssertEqual(expectedViewingKey, viewingKey)
        
    }
    
    func testDeriveViewingKeyFromSpendingKeys() throws {
        XCTAssertEqual(expectedViewingKey, try derivationTool.deriveViewingKey(spendingKey: expectedSpendingKey))
    }
    
    func testDeriveSpendingKeysFromSeed() throws {
        let accounts: Int = 1
        let seedBytes = [UInt8](seedData)
        
        let spendingKeys = try derivationTool.deriveSpendingKeys(seed: seedBytes, numberOfAccounts: accounts)
        XCTAssertEqual(spendingKeys.count, accounts, "the number of viewing keys have to match the number of account requested to derive")
        
        guard let spendingKey = spendingKeys.first else {
            XCTFail("no viewing key generated")
            return
        }
        XCTAssertEqual(expectedSpendingKey, spendingKey)

    }
    
    func testDeriveShieldedAddressFromSeed() throws {
        let seedBytes = [UInt8](seedData)
        
        let shieldedAddress = try derivationTool.deriveShieldedAddress(seed: seedBytes, accountIndex: 0)
        XCTAssertEqual(shieldedAddress, testRecipientAddress)
    }
    
    func testDeriveShieldedAddressFromViewingKey() throws {
        XCTAssertEqual(try derivationTool.deriveShieldedAddress(viewingKey: expectedViewingKey), testRecipientAddress)
    }
    
    func testDeriveTransparentAddressFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentAddress(seed: [UInt8](seedData)), expectedTransparentAddress)
    }
    
    func testIsValidViewingKey() throws {
        XCTAssertTrue(try derivationTool.isValidExtendedViewingKey("zxviews1q0dm7hkzqqqqpqplzv3f50rl4vay8uy5zg9e92f62lqg6gzu63rljety32xy5tcyenzuu3n386ws772nm6tp4sads8n37gff6nxmyz8dn9keehmapk0spc6pzx5uxepgu52xnwzxxnuja5tv465t9asppnj3eqncu3s7g3gzg5x8ss4ypkw08xwwyj7ky5skvnd9ldwj2u8fz2ry94s5q8p9lyp3j96yckudmp087d2jr2rnfuvjp7f56v78vpe658vljjddj7s645q399jd7"))
        
        XCTAssertFalse(try derivationTool.isValidExtendedViewingKey("zxviews1q0dm7hkzky5skvnd9ldwj2u8fz2ry94s5q8p9lyp3j96yckudmp087d2jr2rnfuvjp7f56v78vpe658vljjddj7s645q399jd7"))
    }
    
    func testDeriveSecretKeyFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentPrivateKey(seed: [UInt8](seedData)), "KwqfQoTCuQdCLvzpAEtkt1o8J62WJuZXD3cGRAf1bgmPWuLamHLo")
    }
    
    func testDeriveUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 1)
        XCTAssertEqual(unifiedKeys.count, 1)
        
        XCTAssertEqual(unifiedKeys[0].extfvk, expectedViewingKey)
        
        XCTAssertEqual(expectedTransparentAddress, try derivationTool.deriveTransparentAddressFromPublicKey(unifiedKeys[0].extpub))
    }
    
    func testDeriveQuiteALotOfUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 10)
        XCTAssertEqual(unifiedKeys.count, 10)
        
        XCTAssertEqual(unifiedKeys[0].extfvk, expectedViewingKey)
        
        XCTAssertEqual(expectedTransparentAddress, try derivationTool.deriveTransparentAddressFromPublicKey(unifiedKeys[0].extpub))
    }
    
    func testShouldFailOnInvalidChecksumAddresses() throws {
        let testAddress = "t14oHp2v54vfmdgQ3v3SNuQga8JKHTNi2a1"
        XCTAssertFalse(try derivationTool.isValidTransparentAddress(testAddress))
    }
}
