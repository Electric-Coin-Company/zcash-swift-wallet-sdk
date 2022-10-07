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

    let expectedSpendingKey = UnifiedSpendingKey(
        network: .testnet,
        bytes: Data(base64Encoded: "tNDWwgMg6xrWm9j+A47jcwGN5dh/XkFK6GKTy5TYam5Y8UF6o+kCqQNMS2+dAAAAgAiJqYeoNR3c8a4CGf86m/5GnI0AUAInWtAQ5HAKsbr9jmxmLayd6B/zoSQdJAxSHzFzKr4fZlFvfVlvs/mc8QwAqfuvRiaAmx95knjyp+RKfn8r72qMjYgzEWaj0ei+DGbvf/RToOR9wvevnpsPYkVN0dxg+RCDpqfUX+5K82uvByr+a0STltGka9zx5AiUuSBi/gC+rid7L5P123xTQ+AAQAJO8vbUxpLCW2IvT1HEYhBOtKJDvC1Wp+wmBUmTmhG1aw/JybD+N5IY6PgiY2fiU43KI7tW9HZAlQTKitT+9m8=")!.bytes,
        account: 0
        )

    let expectedViewingKey = UnifiedFullViewingKey(validatedEncoding: "uviewtest12tkgzhaevmw78us4xj2cx6ehxjgpp5da2qwrjqvytztejqfjdmy3e6nryqggtwrjum5cefuuuky8rscuw5dynmjec2tx3kkupqexw4va879pf874kvp6r8kjeza26gysxllaqwl67hm9u0jjke06zc93asrpw4wmy3g0lr9r5cy9pz49q2g7y7wm2pls5akmzhuvqr7khftk93aa2kpvwp7n3sjtmef28mxg3n2rpctsjlgsrhc29g6r23qc0u4tzd8rz8vqq4j7jxummdts8zx0jatzw4l2tl7r3egxhlw587rtkjx0y6dvw4hf4vjprn0qv3hs0sulmavk84ajeewn7argyerpr4essqvgfd0d24jpz6phxlasnd58qazh9d3yc6ad3hc5atp0pkvlq053zga65gscp0pv2plhqj9y2tcmx43thw5g4v8z3unytkc2dhyttuhmnlh5dyz4rmhgfkc96tp8z8rpfe35whjvky0jagz5n7qx", account: 0)

    let expectedSaplingExtendedViewingKey = SaplingExtendedFullViewingKey(validatedEncoding: "zxviewtestsapling1qdxykmuaqqqqpqqg3x5c02p4rhw0rtszr8ln4xl7g6wg6qzsqgn445qsu3cq4vd6l5smlqrckkl2x5rnrauzc4gp665q3zyw0qf2sfdsx5wpp832htfavqk72uchuuvq2dpmgk8jfaza5t5l56u66fpx0sr8ewp9s3wj2txavmhhlazn5rj8mshh470fkrmzg4xarhrqlygg8f486307ujhndwhsw2h7ddzf89k3534aeu0ypz2tjgrzlcqtat380vhe8awm03f58cqgegsaj")

    let expectedSaplingAddress = SaplingAddress(validatedEncoding: "ztestsapling1475xtm56czrzmleqzzlu4cxvjjfsy2p6rv78q07232cpsx5ee52k0mn5jyndq09mampkgvrxnwg")

    let derivationTool = DerivationTool(networkType: NetworkType.testnet)
    let expectedTransparentAddress = TransparentAddress(validatedEncoding: "tmXuTnE11JojToagTqxXUn6KvdxDE3iLKbp")

    func testDeriveViewingKeysFromSeed() throws {
        let seedBytes = [UInt8](seedData)

        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: 0)

        let viewingKey = try derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

        XCTAssertEqual(expectedViewingKey, viewingKey)
    }

    func testDeriveViewingKeyFromSpendingKeys() throws {
//        XCTAssertEqual(
//            expectedViewingKey,
//            try derivationTool.deriveUnifierFullViewingKey(from: expectedSpendingKey)
//        )
    }

    func testDeriveSpendingKeysFromSeed() throws {
        let seedBytes = [UInt8](seedData)

        let spendingKey = try derivationTool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: 0)

        XCTAssertEqual(expectedSpendingKey, spendingKey)

    }

    func testDeriveUnifiedSpendingKeyFromSeed() throws {
        let account = 0
        let seedBytes = [UInt8](seedData)

        XCTAssertNoThrow(try derivationTool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: account))
    }

    func testGetTransparentAddressFromUA() throws {
        XCTAssertEqual(
            try DerivationTool.transparentReceiver(from: testRecipientAddress),
            expectedTransparentAddress
        )
    }

    func testIsValidViewingKey() throws {
        XCTAssertTrue( DerivationTool.rustwelding.isValidSaplingExtendedFullViewingKey("zxviewtestsapling1qdxykmuaqqqqpqqg3x5c02p4rhw0rtszr8ln4xl7g6wg6qzsqgn445qsu3cq4vd6l5smlqrckkl2x5rnrauzc4gp665q3zyw0qf2sfdsx5wpp832htfavqk72uchuuvq2dpmgk8jfaza5t5l56u66fpx0sr8ewp9s3wj2txavmhhlazn5rj8mshh470fkrmzg4xarhrqlygg8f486307ujhndwhsw2h7ddzf89k3534aeu0ypz2tjgrzlcqtat380vhe8awm03f58cqgegsaj",networkType: .testnet))

        XCTAssertFalse( DerivationTool.rustwelding.isValidSaplingExtendedFullViewingKey("zxviews1q0dm7hkzky5skvnd9ldwj2u8fz2ry94s5q8p9lyp3j96yckudmp087d2jr2rnfuvjp7f56v78vpe658vljjddj7s645q399jd7", networkType: .testnet))
    }

    func testDeriveQuiteALotOfUnifiedKeysFromSeed() throws {
        let numberOfAccounts: Int = 10
        let ufvks = try (0 ..< numberOfAccounts)
            .map({
                try derivationTool.deriveUnifiedSpendingKey(
                    seed: [UInt8](seedData),
                    accountIndex: $0
                )

            })
            .map {
                try derivationTool.deriveUnifiedFullViewingKey(
                    from: $0
                )
            }

        XCTAssertEqual(ufvks.count, numberOfAccounts)
        XCTAssertEqual(ufvks[0].account, 0)
        XCTAssertEqual(ufvks[0], expectedViewingKey)
    }

    func testShouldFailOnInvalidChecksumAddresses() throws {
        let testAddress = "t14oHp2v54vfmdgQ3v3SNuQga8JKHTNi2a1"
        XCTAssertFalse(derivationTool.isValidTransparentAddress(testAddress))
    }

    func testSpendingKeyValidationFailsOnInvalidKey() {
        let wrongSpendingKey = "secret-extended-key-main1qw28psv0qqqqpqr2ru0kss5equx6h0xjsuk5299xrsgdqnhe0cknkl8uqff34prwkyuegyhh5d4rdr8025nl7e0hm8r2txx3fuea5mquy3wnsr9tlajsg4wwvw0xcfk8357k4h850rgj72kt4rx3fjdz99zs9f4neda35cq8tn3848yyvlg4w38gx75cyv9jdpve77x9eq6rtl6d9qyh8det4edevlnc70tg5kse670x50764gzhy60dta0yv3wsd4fsuaz686lgszc7nc9vvZzZzZz"

        XCTAssertFalse(derivationTool.isValidSaplingExtendedSpendingKey(wrongSpendingKey))
    }
    // TODO: Address encoding does not catch this test https://github.com/zcash/ZcashLightClientKit/issues/509
//    func testSpendingKeyValidationThrowsWhenWrongNetwork() throws {
//        XCTAssertThrowsError(try derivationTool.isValidExtendedSpendingKey("secret-extended-key-test1qdxykmuaqqqqpqqg3x5c02p4rhw0rtszr8ln4xl7g6wg6qzsqgn445qsu3cq4vd6lk8xce3d4jw7s8ln5yjp6fqv2g0nzue2hc0kv5t004vklvlenncscq9flwh5vf5qnv0hnync72n7gjn70u47765v3kyrxytx50g730svvmhhlazn5rj8mshh470fkrmzg4xarhrqlygg8f486307ujhndwhsw2h7ddzf89k3534aeu0ypz2tjgrzlcqtat380vhe8awm03f58cqe49swv"))
//    }
}

