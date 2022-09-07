//
//  DerivatioToolTestnetTests.swift
//  ZcashLightClientKit-Unit-DerivationToolTests
//
//  Created by Francisco Gindre on 7/26/21.
//
// swift-format-ignore-file

import XCTest
@testable import ZcashLightClientKit

class DerivationToolTestnetTests: XCTestCase {
    var seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread" //TODO: Parameterize this from environment?
    var seedData: Data = Data(base64Encoded: "9VDVOZZZOWWHpZtq1Ebridp3Qeux5C+HwiRR0g7Oi7HgnMs8Gfln83+/Q1NnvClcaSwM4ADFL1uZHxypEWlWXg==")!
    let testRecipientAddress = UnifiedAddress(validatedEncoding: "utest1uqmec4a2njqz2z2rwppchsd06qe7a0jh4jmsqr0yy99m9er9646zlxunf3v8qr0hncgv86e8a62vxy0qa32qzetmj8s57yudmyx9zav6f52nurclsqjkqtjtpz6vg679p6wkczpl2wu") //TODO: Parameterize this from environment
    
    let expectedSpendingKey = SaplingExtendedSpendingKey(validatedEncoding: "secret-extended-key-test1qdxykmuaqqqqpqqg3x5c02p4rhw0rtszr8ln4xl7g6wg6qzsqgn445qsu3cq4vd6lk8xce3d4jw7s8ln5yjp6fqv2g0nzue2hc0kv5t004vklvlenncscq9flwh5vf5qnv0hnync72n7gjn70u47765v3kyrxytx50g730svvmhhlazn5rj8mshh470fkrmzg4xarhrqlygg8f486307ujhndwhsw2h7ddzf89k3534aeu0ypz2tjgrzlcqtat380vhe8awm03f58cqe49swv")
    
    let expectedViewingKey = UnifiedFullViewingKey(validatedEncoding: "uviewtest12tkgzhaevmw78us4xj2cx6ehxjgpp5da2qwrjqvytztejqfjdmy3e6nryqggtwrjum5cefuuuky8rscuw5dynmjec2tx3kkupqexw4va879pf874kvp6r8kjeza26gysxllaqwl67hm9u0jjke06zc93asrpw4wmy3g0lr9r5cy9pz49q2g7y7wm2pls5akmzhuvqr7khftk93aa2kpvwp7n3sjtmef28mxg3n2rpctsjlgsrhc29g6r23qc0u4tzd8rz8vqq4j7jxummdts8zx0jatzw4l2tl7r3egxhlw587rtkjx0y6dvw4hf4vjprn0qv3hs0sulmavk84ajeewn7argyerpr4essqvgfd0d24jpz6phxlasnd58qazh9d3yc6ad3hc5atp0pkvlq053zga65gscp0pv2plhqj9y2tcmx43thw5g4v8z3unytkc2dhyttuhmnlh5dyz4rmhgfkc96tp8z8rpfe35whjvky0jagz5n7qx", account: 0)

    let expectedSaplingExtendedViewingKey = SaplingExtendedFullViewingKey(validatedEncoding: "zxviewtestsapling1qdxykmuaqqqqpqqg3x5c02p4rhw0rtszr8ln4xl7g6wg6qzsqgn445qsu3cq4vd6l5smlqrckkl2x5rnrauzc4gp665q3zyw0qf2sfdsx5wpp832htfavqk72uchuuvq2dpmgk8jfaza5t5l56u66fpx0sr8ewp9s3wj2txavmhhlazn5rj8mshh470fkrmzg4xarhrqlygg8f486307ujhndwhsw2h7ddzf89k3534aeu0ypz2tjgrzlcqtat380vhe8awm03f58cqgegsaj")

    let expectedSaplingAddress = SaplingAddress(validatedEncoding: "ztestsapling1475xtm56czrzmleqzzlu4cxvjjfsy2p6rv78q07232cpsx5ee52k0mn5jyndq09mampkgvrxnwg")
    
    let derivationTool = DerivationTool(networkType: NetworkType.testnet)
    let expectedTransparentAddress = TransparentAddress(validatedEncoding: "tmXuTnE11JojToagTqxXUn6KvdxDE3iLKbp")
    func testDeriveViewingKeysFromSeed() throws {
        let accounts: Int = 1
        let seedBytes = [UInt8](seedData)
        let viewingKeys = try derivationTool.deriveUnifiedFullViewingKeys(seed: seedBytes, numberOfAccounts: accounts)

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
        
        let unifiedAddress = try derivationTool.deriveUnifiedAddress(seed: seedBytes, accountIndex: 0)
        XCTAssertEqual(unifiedAddress, testRecipientAddress)
    }
    
    func testDeriveUnifiedAddressFromViewingKey() throws {
        XCTAssertEqual(try derivationTool.deriveUnifiedAddress(from: expectedViewingKey), testRecipientAddress)
    }
    
    func testDeriveTransparentAddressFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentAddress(seed: [UInt8](seedData)), expectedTransparentAddress)
    }
    
    func testIsValidViewingKey() throws {
        XCTAssertTrue(try derivationTool.isValidExtendedViewingKey(self.expectedSaplingExtendedViewingKey.stringEncoded))
        
        XCTAssertFalse(try derivationTool.isValidExtendedViewingKey("zxviews1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkysswfhjk79n8l99f2grd26dqg6dy3jcmxsaypxfsu6ara6vsk3x8l544uaksstx9zre879mdg7s9a7zurrx6pf5qg2n323js2s3zlu8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszcq7kwxy"))
    }
    
    func testDeriveTransparentAccountPrivateKeyFromSeed() throws {
        XCTAssertEqual(try derivationTool.deriveTransparentAccountPrivateKey(seed: [UInt8](seedData)), TransparentAccountPrivKey(encoding: "xprv9yURYog8Ds8XB36PVzPadbVaCPwVm4CZVMejW9bPPTqBCY8oLssPbe1MhJhPzSbVeg7cWZtuXxuUy2urADuAJUaN27c5f9nErx68SQokG1b"))
    }
    
    func testDeriveUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedFullViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 1)
        XCTAssertEqual(unifiedKeys.count, 1)
        
        XCTAssertEqual(unifiedKeys[0].account, 0)
        XCTAssertEqual(unifiedKeys[0], expectedViewingKey)
    }
    
    func testDeriveQuiteALotOfUnifiedKeysFromSeed() throws {
        let unifiedKeys = try derivationTool.deriveUnifiedFullViewingKeysFromSeed([UInt8](seedData), numberOfAccounts: 10)
        XCTAssertEqual(unifiedKeys.count, 10)
        
        XCTAssertEqual(unifiedKeys[0].account, 0)
        XCTAssertEqual(unifiedKeys[0], expectedViewingKey)
    }

    func testSpendingKeyValidation() throws {
        XCTAssertTrue(try derivationTool.isValidSaplingExtendedSpendingKey(expectedSpendingKey.stringEncoded))
    }

    func testSpendingKeyValidationFailsOnInvalidKey() throws {
        let wrongSpendingKey = "secret-extended-key-test1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkyuegyhh5d4rdr8025nl7e0hm8r2txx3fuea5mquy3wnsr9tlajsg4wwvw0xcfk8357k4h850rgj72kt4rx3fjdz99zs9f4neda35cq8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszc7nc9vvZzZzZz"

        XCTAssertFalse(try derivationTool.isValidSaplingExtendedSpendingKey(wrongSpendingKey))
    }

    // TODO: Address encoding does not catch this test https://github.com/zcash/ZcashLightClientKit/issues/509
//    func testSpendingKeyValidationThrowsWhenWrongNetwork() throws {
//        XCTAssertThrowsError(try derivationTool.isValidExtendedSpendingKey("secret-extended-key-main1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkyuegyhh5d4rdr8025nl7e0hm8r2txx3fuea5mquy3wnsr9tlajsg4wwvw0xcfk8357k4h850rgj72kt4rx3fjdz99zs9f4neda35cq8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszc7nc9vv"))
//    }
}
