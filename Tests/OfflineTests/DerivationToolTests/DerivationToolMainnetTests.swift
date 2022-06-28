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
    let testRecipientAddress = "u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj" //TODO: Parameterize this from environment
    
    let expectedSpendingKey = "secret-extended-key-main1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkyuegyhh5d4rdr8025nl7e0hm8r2txx3fuea5mquy3wnsr9tlajsg4wwvw0xcfk8357k4h850rgj72kt4rx3fjdz99zs9f4neda35cq8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszc7nc9vv"
    
    let expectedViewingKey = "uview1jpddskrm73gpgrsx00y4dryapkhjlzrm5wfdcue77a26u3e7u28qu0xfsgzwt72rs60rjnwujr93al6sxchste78p8vvrlperlvladfwkyryakdutykdcqgqn9dfn9my6k3aka5ej78leksj6aptqs9yzcysszwzwr6zmrcqycxxlg87ten6ers6urmxthe3pvvh07ga7t4uz92a5y0jgej94a7u9q3nezjqj4zm634x2wc2d8d39nu74jew79phf9u025p82d8qshq0pnzcjcnke0g72gva28qsx0wvtad7qjwld5khgudwlxmx24av2mq4k5k9zypheeppcpnujc9rqpm"
    let expectedSaplingExtendedViewingKey = "zxviews1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkysswfhjk79n8l99f2grd26dqg6dy3jcmxsaypxfsu6ara6vsk3x8l544uaksstx9zre879mdg7s9a7zurrx6pf5qg2n323js2s3zlu8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszcq7kwxy"
    
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
        XCTAssertEqual(expectedSaplingExtendedViewingKey, try derivationTool.deriveViewingKey(spendingKey: expectedSpendingKey))
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
    
    func testDeriveUnifiedAddressFromSeed() throws {
        let seedBytes = [UInt8](seedData)
        
        let shieldedAddress = try derivationTool.deriveUnifiedAddress(seed: seedBytes, accountIndex: 0)
        XCTAssertEqual(shieldedAddress, testRecipientAddress)
    }
    
    func testDeriveUnifiedAddressFromViewingKey() throws {
        XCTAssertEqual(try derivationTool.deriveUnifiedAddress(viewingKey: expectedViewingKey), testRecipientAddress)
    }
    
    func testDeriveTransparentAddressFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentAddress(seed: [UInt8](seedData)), expectedTransparentAddress)
    }
    
    func testIsValidViewingKey() throws {
        XCTAssertTrue(try derivationTool.isValidExtendedViewingKey("zxviews1q0dm7hkzqqqqpqplzv3f50rl4vay8uy5zg9e92f62lqg6gzu63rljety32xy5tcyenzuu3n386ws772nm6tp4sads8n37gff6nxmyz8dn9keehmapk0spc6pzx5uxepgu52xnwzxxnuja5tv465t9asppnj3eqncu3s7g3gzg5x8ss4ypkw08xwwyj7ky5skvnd9ldwj2u8fz2ry94s5q8p9lyp3j96yckudmp087d2jr2rnfuvjp7f56v78vpe658vljjddj7s645q399jd7"))
        
        XCTAssertFalse(try derivationTool.isValidExtendedViewingKey("zxviews1q0dm7hkzky5skvnd9ldwj2u8fz2ry94s5q8p9lyp3j96yckudmp087d2jr2rnfuvjp7f56v78vpe658vljjddj7s645q399jd7"))
    }
    
    func testDeriveTransparentAccountPrivateKeyFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentAccountPrivateKey(seed: [UInt8](seedData)), "xprv9yCTU6giJ1qZ1DLC5rc7KMzwY9s8rSRXYqmoAKffAExpUVUKLhcdvN9ERdxjEW8tQq4pxerLKZE3WcNUKZCeX19rVTxpV2msTyNMNiFT3Nw")
    }
    
    func testDeriveUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedFullViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 1)
        XCTAssertEqual(unifiedKeys.count, 1)
        
        XCTAssertEqual(unifiedKeys[0].account, 0)
        XCTAssertEqual(unifiedKeys[0].encoding, expectedViewingKey)
    }
    
    func testDeriveQuiteALotOfUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedFullViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 10)
        XCTAssertEqual(unifiedKeys.count, 10)
        
        XCTAssertEqual(unifiedKeys[0].account, 0)
        XCTAssertEqual(unifiedKeys[0].encoding, expectedViewingKey)
    }
    
    func testShouldFailOnInvalidChecksumAddresses() throws {
        let testAddress = "t14oHp2v54vfmdgQ3v3SNuQga8JKHTNi2a1"
        XCTAssertFalse(try derivationTool.isValidTransparentAddress(testAddress))
    }
}
